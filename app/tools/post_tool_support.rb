# frozen_string_literal: true

module PostToolSupport
  private
    def resolve_post(id_or_slug)
      key = id_or_slug.to_s
      key.match?(/\A\d+\z/) ? Post.find_by(id: key) : Post.find_by(slug: key)
    end

    # Explorable < HtmlPage < Page, so the most specific kind is asked about first or
    # every HTML page reports itself as a plain page and agents send it to the wrong tool.
    def kind_of(post)
      case post
      when Explorable then "explorable"
      when HtmlPage then "html_page"
      when Page     then "page"
      when Doc      then "doc"
      else               "article"
      end
    end

    # A doc is a draft in the column and nothing like one in meaning: it isn't on its way
    # anywhere. Saying "private" keeps an agent from offering to publish it.
    def status_of(post)
      if post.is_a?(Doc)
        "private"
      elsif post.published?
        "published"
      elsif post.scheduled?
        "scheduled"
      else
        "draft"
      end
    end

    def public_url(post) = post.public_url

    def edit_url(post)
      helpers = Rails.application.routes.url_helpers
      options = { host: Setting.current.production_host, protocol: "https" }
      case post
      when Explorable then helpers.edit_writing_explorable_url(post, **options)
      when HtmlPage then helpers.edit_writing_html_page_url(post, **options)
      when Page     then helpers.edit_writing_page_url(post, **options)
      when Doc      then helpers.edit_writing_doc_url(post, **options)
      else               helpers.edit_writing_post_url(post, **options)
      end
    end

    # The class a kind names. A doc is a kind like any other here: created, read, patched
    # and deleted through the post tools, because it is written on the same body.
    KINDS = { "article" => Post, "page" => Page, "doc" => Doc }.freeze

    def resolve_doc(id_or_slug)
      resolve_post(id_or_slug).then { |post| post if post.is_a?(Doc) }
    end

    def find_or_create_tags(names)
      names.filter_map do |name|
        clean = name.to_s.strip
        Tag.find_or_create_by(name: clean) if clean.present?
      end
    end
end
