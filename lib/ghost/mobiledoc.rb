# Converts a Ghost 4 mobiledoc document (version 0.3.1) into semantic HTML that
# mirrors Koenig's rendered output closely enough for Action Text + our kg-card CSS.
#
# This is the fallback body source: the importer prefers Ghost's own rendered
# `html` and only reaches for this when a row has none (empty drafts). It is
# deliberately a small, throwaway codec covering exactly the card vocabulary
# present in the export (plan §1): image, hr, embed, html, gallery, code,
# bookmark, toggle, markdown, callout, button.
module Ghost
  class Mobiledoc
    MARKUP_SECTION = 1
    LIST_SECTION   = 3
    CARD_SECTION   = 10

    def self.to_html(json)
      new(json).to_html
    end

    def initialize(json)
      @doc    = json.is_a?(String) ? JSON.parse(json) : (json || {})
      @cards  = @doc["cards"]   || []
      @markups = @doc["markups"] || []
      @atoms  = @doc["atoms"]   || []
    end

    def to_html
      (@doc["sections"] || []).map { |section| render_section(section) }.join("\n")
    end

    private
      def render_section(section)
        case section.first
        when MARKUP_SECTION then render_markup_section(section)
        when LIST_SECTION   then render_list_section(section)
        when CARD_SECTION   then render_card(@cards[section[1]])
        else ""
        end
      end

      def render_markup_section(section)
        _type, tag, markers = section
        inner = render_markers(markers)
        return "" if inner.strip.empty? && tag == "p"
        "<#{tag}>#{inner}</#{tag}>"
      end

      def render_list_section(section)
        _type, tag, items = section
        lis = items.map { |markers| "<li>#{render_markers(markers)}</li>" }.join
        "<#{tag}>#{lis}</#{tag}>"
      end

      # markers: [textType, openMarkupIndexes, numClosed, value]
      def render_markers(markers)
        open_stack = []
        out = +""
        (markers || []).each do |type, opened, num_closed, value|
          opened.each do |idx|
            out << open_tag(@markups[idx])
            open_stack << @markups[idx].first
          end
          out << (type == 1 ? atom_text(value) : ERB::Util.html_escape(value.to_s))
          num_closed.times do
            tag = open_stack.pop
            out << "</#{tag}>"
          end
        end
        out
      end

      def open_tag(markup)
        tag, attrs = markup
        return "<#{tag}>" if attrs.nil? || attrs.empty?
        pairs = attrs.each_slice(2).map { |k, v| %(#{k}="#{ERB::Util.html_escape(v)}") }.join(" ")
        "<#{tag} #{pairs}>"
      end

      def atom_text(index)
        atom = @atoms[index]
        atom ? ERB::Util.html_escape(atom[1].to_s) : ""
      end

      def render_card(card)
        return "" unless card
        name, payload = card
        payload ||= {}
        send("card_#{name}", payload)
      rescue NoMethodError
        # Unknown card: preserve nothing silently — flag with a comment so a
        # human can spot it, but the raw mobiledoc is always kept in raw_source.
        "<!-- unconverted ghost card: #{name} -->"
      end

      def card_hr(_)
        "<hr>"
      end

      def card_image(p)
        img = %(<img src="#{ERB::Util.html_escape(p["src"])}")
        img << %( width="#{p["width"]}") if p["width"]
        img << %( height="#{p["height"]}") if p["height"]
        img << %( alt="#{ERB::Util.html_escape(p["alt"])}") if p["alt"].present?
        img << ">"
        caption = p["caption"].present? ? %(<figcaption>#{p["caption"]}</figcaption>) : ""
        %(<figure class="kg-card kg-image-card#{caption.empty? ? "" : " kg-card-hascaption"}">#{img}#{caption}</figure>)
      end

      def card_embed(p)
        # Ghost stores the provider-rendered HTML (tweet blockquote, iframe, ...).
        html = p["html"].presence || %(<a href="#{ERB::Util.html_escape(p["url"])}">#{ERB::Util.html_escape(p["url"])}</a>)
        %(<figure class="kg-card kg-embed-card">#{html}</figure>)
      end

      def card_html(p)
        p["html"].to_s
      end

      def card_gallery(p)
        images = (p["images"] || []).map do |img|
          %(<div class="kg-gallery-image"><img src="#{ERB::Util.html_escape(img["src"])}" width="#{img["width"]}" height="#{img["height"]}"></div>)
        end.join
        caption = p["caption"].present? ? %(<figcaption>#{p["caption"]}</figcaption>) : ""
        %(<figure class="kg-card kg-gallery-card kg-width-wide"><div class="kg-gallery-container">#{images}</div>#{caption}</figure>)
      end

      def card_code(p)
        lang = p["language"].present? ? %( class="language-#{ERB::Util.html_escape(p["language"])}") : ""
        %(<figure class="kg-card kg-code-card"><pre><code#{lang}>#{ERB::Util.html_escape(p["code"])}</code></pre></figure>)
      end

      def card_bookmark(p)
        m = p["metadata"] || {}
        thumb = m["thumbnail"].present? ? %(<div class="kg-bookmark-thumbnail"><img src="#{ERB::Util.html_escape(m["thumbnail"])}"></div>) : ""
        %(<figure class="kg-card kg-bookmark-card"><a class="kg-bookmark-container" href="#{ERB::Util.html_escape(p["url"])}"><div class="kg-bookmark-content"><div class="kg-bookmark-title">#{ERB::Util.html_escape(m["title"])}</div><div class="kg-bookmark-description">#{ERB::Util.html_escape(m["description"])}</div></div>#{thumb}</a></figure>)
      end

      def card_toggle(p)
        %(<details class="kg-card kg-toggle-card"><summary>#{p["heading"]}</summary><div class="kg-toggle-content">#{p["content"]}</div></details>)
      end

      def card_callout(p)
        emoji = p["calloutEmoji"].present? ? %(<div class="kg-callout-emoji">#{p["calloutEmoji"]}</div>) : ""
        %(<div class="kg-card kg-callout-card kg-callout-card-#{p["backgroundColor"]}">#{emoji}<div class="kg-callout-text">#{ERB::Util.html_escape(p["calloutText"])}</div></div>)
      end

      def card_button(p)
        align = p["alignment"] || "center"
        %(<div class="kg-card kg-button-card kg-align-#{align}"><a href="#{ERB::Util.html_escape(p["buttonUrl"])}" class="kg-btn kg-btn-accent">#{ERB::Util.html_escape(p["buttonText"])}</a></div>)
      end

      # One markdown card in the corpus, and only reached as a fallback. Handle
      # fenced code blocks (the actual usage) without pulling in a markdown gem.
      def card_markdown(p)
        md = p["markdown"].to_s
        if md.strip.start_with?("```")
          body = md.strip.gsub(/\A```[^\n]*\n?/, "").gsub(/```\s*\z/, "")
          %(<pre><code>#{ERB::Util.html_escape(body)}</code></pre>)
        else
          paras = md.split(/\n{2,}/).map { |para| "<p>#{ERB::Util.html_escape(para.strip)}</p>" }
          paras.join("\n")
        end
      end
  end
end
