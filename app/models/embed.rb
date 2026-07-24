# Turns a pasted URL into the same provider HTML Ghost stored for its embed
# cards, so a newly embedded tweet or video renders through the exact
# kg-embed-card path (and tweets Stimulus controller) as the imported ones.
#
# Not persisted — an Embed exists only to convert a URL to markup for the editor.
class Embed
  YOUTUBE = %r{(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([\w-]+)}
  TWITTER = %r{(?:twitter\.com|x\.com)/[^/]+/status/(\d+)}

  attr_reader :url

  def initialize(url)
    @url = url.to_s.strip
  end

  # The kg-embed-card figure to drop into the body, or nil for an unsupported URL.
  def to_html
    youtube_html || twitter_html
  end

  private
    def youtube_html
      id = url[YOUTUBE, 1] or return
      figure %(<iframe width="560" height="315" src="https://www.youtube.com/embed/#{id}" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>)
    end

    def twitter_html
      return unless url.match?(TWITTER)

      href = ERB::Util.html_escape(url)
      figure %(<blockquote class="twitter-tweet"><a href="#{href}">#{href}</a></blockquote>)
    end

    def figure(inner)
      %(<figure class="kg-card kg-embed-card">#{inner}</figure>)
    end
end
