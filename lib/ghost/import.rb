# Imports a Ghost 4 JSON export into the app. Idempotent, keyed on Ghost slugs:
# safe to re-run after a fresh export at cutover (plan §4).
#
#   Ghost::Import.new("data/ghost-export-2026-07-14.json").run
#
# Body source: Ghost's own rendered `html` when present (clean semantic markup);
# the Mobiledoc converter only fills in rows whose `html` is empty. The raw
# mobiledoc JSON is always retained in Post#raw_source so nothing is ever lost.
#
# Images: body/feature URLs are normalised to root-relative /content/images/
# paths (Ghost stores them as __GHOST_URL__/… and with /size/wN/ variants). The
# whole image tree is mirrored into public/content/images/ separately, so every
# link resolves without ActiveStorage. New uploads use ActiveStorage; migrated
# inline images stay plain URLs (plan §4 — belt and braces, zero code).
require "loofah"

module Ghost
  class Import
    Report = Struct.new(:posts, :pages, :tags, :taggings, :converted_bodies, keyword_init: true)

    # Elements whose CONTENTS are code/style, not prose. Action Text's sanitizer
    # drops these tags but keeps their text nodes, so a <style> block smuggled
    # inside a Ghost HTML card (e.g. a Kindle-highlights export) would render as
    # visible body prose. We remove the whole node — tag and children — up front.
    NON_CONTENT_ELEMENTS = %w[ style script ].freeze

    def initialize(path)
      @data = JSON.parse(File.read(path)).dig("db", 0, "data")
    end

    # Strip <style>/<script> elements — tag AND text — via a Loofah scrubber, so
    # no regex ever parses HTML. Returns the cleaned HTML string.
    def self.strip_non_content(html)
      return html if html.blank?

      scrubber = Loofah::Scrubber.new do |node|
        if NON_CONTENT_ELEMENTS.include?(node.name)
          node.remove
          Loofah::Scrubber::STOP
        end
      end
      Loofah.fragment(html).scrub!(scrubber).to_html
    end

    def self.normalize_urls(text)
      return text if text.blank?

      text
        .gsub("__GHOST_URL__", "")
        .gsub(%r{https?://(?:www\.)?nityesh\.com}, "")
        .gsub(%r{/content/images/size/[^/"']+/}, "/content/images/")
    end

    # The canonical body pipeline, exposed for the one-off style-leak repair
    # (lib/tasks/ghost_import.rake): re-derive a clean body from a post's retained
    # mobiledoc through exactly the same strip + URL-normalise steps used at import.
    def self.body_from_raw_source(raw_source)
      html = Ghost::Mobiledoc.to_html(raw_source)
      normalize_urls(strip_non_content(html))
    end

    def run
      report = Report.new(posts: 0, pages: 0, tags: 0, taggings: 0, converted_bodies: 0)

      ActiveRecord::Base.transaction do
        import_tags(report)
        import_posts(report)
        import_taggings(report)
      end

      # After commit, so no deferred touch (ActionText/tagging `touch: true`) can
      # clobber the restored updated_at.
      restore_timestamps

      report
    end

    private
      def import_tags(report)
        @data["tags"].each do |row|
          tag = Tag.find_or_initialize_by(slug: row["slug"])
          tag.name = row["name"]
          tag.description = row["description"]
          tag.save!
          report.tags += 1
        end
      end

      def import_posts(report)
        meta = @data["posts_meta"].index_by { |m| m["post_id"] }

        @data["posts"].each do |row|
          klass  = row["type"] == "page" ? Page : Post
          post   = klass.find_or_initialize_by(slug: row["slug"])
          m      = meta[row["id"]] || {}

          html, converted = body_html(row)
          report.converted_bodies += 1 if converted

          post.assign_attributes(
            ghost_id:              row["id"],
            title:                 row["title"].presence || "(untitled)",
            status:                row["status"],
            excerpt:               row["custom_excerpt"],
            feature_image:         self.class.normalize_urls(row["feature_image"]),
            feature_image_caption: m["feature_image_caption"],
            meta_title:            m["meta_title"],
            meta_description:      m["meta_description"],
            raw_source:            row["mobiledoc"],
            published_at:          row["published_at"]
          )
          post.body = self.class.normalize_urls(html)
          post.save!

          row["type"] == "page" ? report.pages += 1 : report.posts += 1
        end
      end

      # Restore Ghost's own created/updated timestamps in a final pass, after
      # tagging (`touch: true`) has finished re-stamping updated_at. update_columns
      # writes them directly, skipping validations and timestamp callbacks.
      def restore_timestamps
        by_slug = Post.all.index_by(&:slug)
        @data["posts"].each do |row|
          post = by_slug[row["slug"]]
          post&.update_columns(created_at: row["created_at"], updated_at: row["updated_at"])
        end
      end

      def import_taggings(report)
        posts = Post.all.index_by(&:slug)
        tags  = Tag.all.index_by { |t| t.id }
        ghost_posts = @data["posts"].index_by { |r| r["id"] }
        ghost_tags  = @data["tags"].index_by { |r| r["id"] }

        @data["posts_tags"].sort_by { |r| r["sort_order"] || 0 }.each do |row|
          gp = ghost_posts[row["post_id"]]
          gt = ghost_tags[row["tag_id"]]
          next unless gp && gt

          post = posts[gp["slug"]]
          tag  = Tag.find_by(slug: gt["slug"])
          next unless post && tag

          Tagging.find_or_create_by!(post: post, tag: tag)
          report.taggings += 1
        end
      end

      # Prefer Ghost's rendered HTML; fall back to converting mobiledoc. Either
      # way, strip <style>/<script> element contents before storage.
      # Returns [html, converted?].
      def body_html(row)
        html, converted =
          if row["html"].present?
            [ row["html"], false ]
          else
            [ Ghost::Mobiledoc.to_html(row["mobiledoc"]), true ]
          end
        [ self.class.strip_non_content(html), converted ]
      end
  end
end
