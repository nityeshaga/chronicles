require "test_helper"

class CodeHighlightingTest < ActiveSupport::TestCase
  test "a ruby block gets Rouge's token spans and a language label" do
    html = CodeHighlighting.add(%(<pre data-language="ruby">def publish<br>end</pre>))

    assert_includes html, %(<pre data-language="ruby" class="highlight")
    assert_includes html, %(<span class="k">def</span> <span class="nf">publish</span>)
    assert_includes html, %(<span class="highlight__language">Ruby</span>)
  end

  test "the editor's line breaks become newlines and no inline style is emitted" do
    html = CodeHighlighting.add(%(<pre data-language="ruby">def publish<br>  save<br>end</pre>))

    assert_includes html, "<span class=\"nf\">publish</span>\n  <span class=\"n\">save</span>\n<span class=\"k\">end</span>"
    assert_not_includes html, "<br>"
    assert_not_includes html, "style="
  end

  test "a language hint spelled as a class is honoured, on the pre or the code inside it" do
    on_code = CodeHighlighting.add(%(<pre><code class="language-python">print("hi")\n</code></pre>))
    on_pre = CodeHighlighting.add(%(<pre class="language-javascript">const a = 1</pre>))

    assert_includes on_code, %(data-language="python")
    assert_includes on_code, %(<span class="highlight__language">Python</span>)
    assert_includes on_pre, %(data-language="javascript")
    assert_includes on_pre, %(<span class="kd">const</span>)
  end

  test "a language is matched without regard to case or stray whitespace" do
    html = CodeHighlighting.add(%(<pre><code class="language-Ruby">def a</code></pre><pre data-language="javascript ">const a = 1</pre>))

    assert_includes html, %(data-language="ruby")
    assert_includes html, %(<span class="highlight__language">Ruby</span>)
    assert_includes html, %(data-language="javascript")
    assert_includes html, %(<span class="highlight__language">JavaScript</span>)
  end

  test "the picker's clike reads as C" do
    html = CodeHighlighting.add(%(<pre data-language="clike">int x;</pre>))

    assert_includes html, %(<span class="kt">int</span>)
    assert_includes html, %(<span class="highlight__language">C</span>)
  end

  test "text that looks like markup stays text" do
    html = CodeHighlighting.add(%(<pre data-language="plain">&lt;script&gt;alert(1)&lt;/script&gt;</pre>))

    assert_includes html, "&lt;script&gt;alert(1)&lt;/script&gt;"
    assert_not_includes html, "<script>"
  end

  test "an unknown language and a block with none render as plain text, unlabelled" do
    unknown = CodeHighlighting.add(%(<pre data-language="brainfudge">++.</pre>))
    none = CodeHighlighting.add(%(<pre>just text</pre>))

    assert_includes unknown, %(<code data-clipboard-target="source">++.</code>)
    assert_not_includes unknown, "highlight__language"
    assert_includes none, %(data-language="plain")
    assert_includes none, %(<code data-clipboard-target="source">just text</code>)
    assert_not_includes none, "highlight__language"
  end

  test "every block carries the copy button and the editor-only attribute is dropped" do
    html = CodeHighlighting.add(%(<pre data-language="ruby" data-highlight-language="ruby">a</pre>))

    assert_includes html, %(data-controller="clipboard")
    assert_includes html, %(<button type="button" class="highlight__copy" data-action="clipboard#copy" data-clipboard-target="button">Copy</button>)
    assert_not_includes html, "data-highlight-language"
  end

  test "running the pass over its own output changes nothing" do
    once = CodeHighlighting.add(%(<p>Intro</p><pre data-language="ruby">def a<br>end</pre><pre>plain</pre>))

    assert_includes once, %(data-highlighted="true")
    assert_equal once, CodeHighlighting.add(once)
  end

  test "markup that is not a code block passes through untouched" do
    html = %(<p>Hello <code>inline</code></p><h2>Title</h2>)

    assert_equal html, CodeHighlighting.add(html)
  end
end
