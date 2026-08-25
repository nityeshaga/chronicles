# The colour on every code block, derived at render. The editor highlights with Prism as
# the writer types, but those token spans are the canvas's own and leave with the export:
# what the body stores is <pre data-language="ruby"> with the lines joined by <br>, and
# nothing else. Rouge re-derives the colouring from that on the way out — inside the post's
# fragment cache, so it runs once per change — and the writer's preview renders the same
# partial, so it shows the same page.
#
# Only class names are emitted (Rouge's HTML formatter, no inline styles); the palette is
# the stylesheet's, and the stylesheet maps the editor's Prism variables onto the same
# colours so the canvas reads like the page. A language Rouge has no lexer for renders as
# plain text rather than as nothing, and a block with no language at all is plain text too,
# so every block wears the same chrome: the copy button, and a label when there is a
# language to name.
#
# Runs after sanitization, which is what lets the button carry data-* attributes the
# allow-list would otherwise strip — and why the pass must stay inside the render, never
# in the stored body.
module CodeHighlighting
  def self.add(html)
    ActionText::Fragment.wrap(html.to_s).update do |source|
      source.css("pre").each { |pre| Block.new(pre).highlight }
    end.to_html.html_safe
  end

  class Block
    LANGUAGE_CLASS = /\Alanguage-(.+)\z/

    def initialize(pre)
      @pre = pre
    end

    # A highlighted block is left alone, so running the pass over its own output changes
    # nothing.
    def highlight
      return if @pre["data-highlighted"]

      code = source
      @pre.add_class("highlight")
      @pre["data-language"] = language
      @pre["data-highlighted"] = "true"
      @pre.remove_attribute("data-highlight-language")
      @pre["data-controller"] = "clipboard"
      @pre["data-clipboard-supported-class"] = "highlight--copyable"
      @pre.inner_html = %(<code data-clipboard-target="source">#{formatter.format(lexer.lex(code))}</code><span class="highlight__tools">#{label}#{button}</span>)
    end

    private
      # The editor exports a line break as <br>; Ghost and a pasted fence carry real
      # newlines. Rouge wants the text, so both become newlines before it looks.
      def source
        @pre.css("br").each { |br| br.replace("\n") }
        @pre.text.sub(/\n\z/, "")
      end

      # The editor stamps data-language; Ghost's importer and a markdown fence spell the
      # same thing as class="language-ruby", on the pre or on the code inside it.
      def language
        @language ||= (@pre["data-language"].presence || class_language(@pre) || class_language(@pre.at_css("code")) || "plain").strip.downcase
      end

      def class_language(element)
        element&.classes&.filter_map { |name| name[LANGUAGE_CLASS, 1] }&.first
      end

      # The editor's picker offers Prism's generic "clike"; Rouge has no such lexer, and
      # C is the closest reading of code a writer filed under it.
      LEXER_ALIASES = { "clike" => "c" }

      def lexer
        @lexer ||= (Rouge::Lexer.find(LEXER_ALIASES.fetch(language, language)) || Rouge::Lexers::PlainText).new
      end

      def formatter = Rouge::Formatters::HTML.new

      def label
        return if lexer.is_a?(Rouge::Lexers::PlainText)

        %(<span class="highlight__language">#{ERB::Util.html_escape(lexer.class.title)}</span>)
      end

      def button
        %(<button type="button" class="highlight__copy" data-action="clipboard#copy" data-clipboard-target="button">Copy</button>)
      end
  end
end
