require "test_helper"

class CreateHtmlCardToolTest < ActiveSupport::TestCase
  CLEAN = %(<style>@scope { .chart { display: grid } }</style><div class="chart">Revenue by quarter</div>)

  setup do
    Thread.current[:mcp_current_user] = users(:nityesh)
    @tool = CreateHtmlCardTool.new
  end

  teardown do
    Thread.current[:mcp_current_user] = nil
  end

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, @tool.call(html: CLEAN)
  end

  test "stores the markup and returns an attachment that resolves back to the card" do
    result = @tool.call(html: CLEAN)

    card = HtmlCard.find(result[:id])
    assert_equal CLEAN, card.content
    assert_equal [ card ], ActionText::Content.new(result[:attachment_html]).attachables
    assert_not_includes result[:attachment_html], "chart"
    assert_includes result[:message], "body_patches"
  end

  test "a clean card is reported, not warned about" do
    result = @tool.call(html: CLEAN)

    assert_nil result[:warnings]
    assert_includes result[:stored], "#{CLEAN.bytesize} bytes"
    assert_includes result[:stored], "Revenue by quarter"
  end

  test "the report names what a card with no readable text costs" do
    assert_includes @tool.call(html: %(<canvas id="chart"></canvas>))[:stored], "no text outside its script and style"
  end

  test "markup that arrived escaped reads back as its own source" do
    assert_includes @tool.call(html: "&lt;div&gt;drawn&lt;/div&gt;")[:stored], "<div>drawn</div>"
  end

  test "a relative reference warns and points at upload_image" do
    warning = @tool.call(html: %(<img src="img/chart.png">))[:warnings].find { |w| w.start_with?("Relative references") }

    assert_includes warning, "img/chart.png"
    assert_includes warning, "upload_image"
  end

  test "absolute references and anchors pass unremarked" do
    html = %(<img src="https://cdn.example.com/a.png"><a href="#top">top</a><img src="/content/images/hero.png">)

    assert_nil @tool.call(html: html)[:warnings]
  end

  test "a bare element selector warns and names the fix" do
    warning = @tool.call(html: %(<style>td { padding: 7px }</style>))[:warnings].find { |w| w.start_with?("Bare element selectors") }

    assert_includes warning, "td"
    assert_includes warning, "@scope"
  end

  test "@scope and class-prefixed selectors raise no selector warning" do
    assert_nil @tool.call(html: %(<style>@scope { td { padding: 7px } }</style>))[:warnings]
    assert_nil @tool.call(html: %(<style>.chart td { padding: 7px }</style>))[:warnings]
  end

  test "a relative src and a bare selector in one card warn separately" do
    warnings = @tool.call(html: %(<style>td { padding: 7px }</style><img src="img/chart.png">))[:warnings]

    assert warnings.any? { |w| w.start_with?("Relative references") }
    assert warnings.any? { |w| w.start_with?("Bare element selectors") }
  end

  test "document.write is called out" do
    warnings = @tool.call(html: %(<script>document.write("<b>hi</b>")</script>))[:warnings]

    assert warnings.any? { |w| w.start_with?("document.write") }
  end

  test "an external script src is called out" do
    warnings = @tool.call(html: %(<script src="https://cdn.example.com/chart.js"></script>))[:warnings]

    assert warnings.any? { |w| w.include?("back-button restore") }
  end

  test "customElements.define is called out" do
    warnings = @tool.call(html: %(<script>customElements.define("my-chart", MyChart)</script>))[:warnings]

    assert warnings.any? { |w| w.start_with?("customElements.define") }
  end

  test "inline script with none of the hazards raises no script warning" do
    html = %(<div class="chart"></div><script>document.querySelector(".chart").textContent = "drawn"</script>)

    assert_nil @tool.call(html: html)[:warnings]
  end

  test "blank markup is refused by the model, not stored" do
    assert_no_difference "HtmlCard.count" do
      assert_includes @tool.call(html: "   ")[:error], "Content"
    end
  end
end
