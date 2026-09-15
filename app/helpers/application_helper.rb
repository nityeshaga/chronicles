module ApplicationHelper
  # Site identity (title, author, host, social/OG/JSON-LD fields) lives in the
  # single Setting row — read it via Setting.current.

  # Public post/tag URLs canonically carry a trailing slash (Ghost parity, enforced by
  # ApplicationController#redirect_to_trailing_slash). Bake it in so no call site has to
  # remember `trailing_slash: true` — one forgotten flag serves a link that eats a 301.
  # Admin (/writing) paths stay bare, so these live only for the public routes.
  def public_post_path(post) = post_path(post, trailing_slash: true)
  def public_post_url(post)  = post_url(post, trailing_slash: true)
  def public_tag_path(tag)   = tag_path(tag, trailing_slash: true)
  def public_tag_url(tag)    = tag_url(tag, trailing_slash: true)

  # Ghost rendered ~265 words/minute; match its "X min read" label. The editor bar counts
  # the same words at the same speed, so the number the writer watches climb is the number
  # the reader is promised — the speed rides onto the bar as data rather than being typed
  # a second time in JavaScript.
  READING_SPEED = 265

  def word_count(post)
    strip_tags(post.body.to_s).split.size
  end

  def reading_time(post)
    [ (word_count(post) / READING_SPEED.to_f).ceil, 1 ].max
  end

  # Absolute URL for og/canonical tags, honoring the mirrored image tree.
  def site_url(path)
    URI.join(request.base_url + "/", path.to_s.sub(%r{\A/}, "")).to_s
  end

  # Ghost stamps ISO-8601 with millisecond precision and a literal Z, e.g.
  # 2022-09-19T12:34:56.000Z — used in article:*_time, JSON-LD and sitemap lastmod.
  def ghost_time(time)
    time&.utc&.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
  end

  # RFC-822 with a "GMT" suffix (not +0000), matching Ghost's RSS pubDate/lastBuildDate.
  def rss_time(time)
    time&.utc&.strftime("%a, %d %b %Y %H:%M:%S GMT")
  end

  # Ghost's Article/Series/WebSite schemas all carry the same publisher block.
  def schema_publisher
    setting = Setting.current
    {
      "@type": "Organization",
      "name": setting.site_title,
      "url": site_url(""),
      "logo": { "@type": "ImageObject", "url": site_url(setting.site_logo) }
    }
  end

  def schema_author
    setting = Setting.current
    {
      "@type": "Person",
      "name": setting.author_name,
      "image": {
        "@type": "ImageObject",
        "url": site_url(setting.author_image_full),
        "width": setting.author_image_size,
        "height": setting.author_image_size
      },
      "url": site_url(setting.author_path),
      "sameAs": []
    }
  end
end
