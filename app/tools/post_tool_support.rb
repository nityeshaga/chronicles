# frozen_string_literal: true

module PostToolSupport
  private
    def resolve_post(id_or_slug)
      key = id_or_slug.to_s
      key.match?(/\A\d+\z/) ? Post.find_by(id: key) : Post.find_by(slug: key)
    end

    # HtmlPage < Page, so it has to be asked about first or every HTML page reports
    # itself as a plain page and agents send it to the wrong tool.
    def kind_of(post)
      case post
      when HtmlPage then "html_page"
      when Page     then "page"
      else               "article"
      end
    end

    def status_of(post)
      if post.published?
        "published"
      elsif post.scheduled?
        "scheduled"
      else
        "draft"
      end
    end

    def public_url(post)
      Rails.application.routes.url_helpers.post_url(
        post,
        host: Setting.current.production_host,
        protocol: "https",
        trailing_slash: true
      )
    end

    def edit_url(post)
      helpers = Rails.application.routes.url_helpers
      options = { host: Setting.current.production_host, protocol: "https" }
      case post
      when HtmlPage then helpers.edit_writing_html_page_url(post, **options)
      when Page     then helpers.edit_writing_page_url(post, **options)
      else               helpers.edit_writing_post_url(post, **options)
      end
    end

    def find_or_create_tags(names)
      names.filter_map do |name|
        clean = name.to_s.strip
        Tag.find_or_create_by(name: clean) if clean.present?
      end
    end
end
