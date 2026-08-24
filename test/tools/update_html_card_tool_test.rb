require "test_helper"

class UpdateHtmlCardToolTest < ActiveSupport::TestCase
  CLEAN = %(<style>@scope { .chart { display: grid } }</style><div class="chart">Revenue by quarter</div>)

  setup do
    Thread.current[:mcp_current_user] = users(:nityesh)
    @tool = UpdateHtmlCardTool.new
    @card = HtmlCard.create!(content: CLEAN)
  end

  teardown do
    Thread.current[:mcp_current_user] = nil
  end

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, @tool.call(id: @card.id, html: CLEAN)
  end

  test "returns a recovery error when not found" do
    result = @tool.call(id: 0, html: CLEAN)

    assert_equal ToolErrors::HTML_CARD_NOT_FOUND, result
    assert_includes result[:error], "create_html_card"
  end

  test "replaces the markup wholesale and leaves the posts carrying it alone" do
    post = Post.create!(title: "Carries a card", body: %(<action-text-attachment sgid="#{@card.attachable_sgid}"></action-text-attachment>))
    body_was = post.body.body.to_html

    result = @tool.call(id: @card.id, html: %(<div class="chart">Revenue by month</div>))

    assert_equal %(<div class="chart">Revenue by month</div>), @card.reload.content
    assert_equal body_was, post.reload.body.body.to_html
    assert_equal [ @card ], post.body.body.attachables
    assert_includes result[:message], "now serves the new markup"
  end

  test "the new markup is screened the same way" do
    warnings = @tool.call(id: @card.id, html: %(<style>td { padding: 7px }</style><img src="img/chart.png">))[:warnings]

    assert warnings.any? { |w| w.start_with?("Relative references") }
    assert warnings.any? { |w| w.start_with?("Bare element selectors") }
  end

  test "a clean replacement is reported, not warned about" do
    result = @tool.call(id: @card.id, html: CLEAN)

    assert_nil result[:warnings]
    assert_includes result[:stored], "Revenue by quarter"
  end

  test "blank markup is refused and the card keeps its bytes" do
    assert_includes @tool.call(id: @card.id, html: "   ")[:error], "Content"
    assert_equal CLEAN, @card.reload.content
  end
end
