require "test_helper"

# The shelves: one page per kind of thing in the log, and the essays by era. Each reads
# the same published ships the homepage does, so a draft never reaches a shelf either.
class ShelvesControllerTest < ActionDispatch::IntegrationTest
  test "the apps page shelves the app ships as cards, with their line from the log" do
    get "/apps/"
    assert_response :success
    assert_select ".ph .kick", text: "The catalogue · 1 app in print"
    assert_select ".machines a.mach[href=?]", "https://curatedconnections.io" do
      assert_select ".meta h4", text: "Curated Connections."
      assert_select ".meta p", text: "Self-driving community software."
      assert_select ".meta .mono", text: "Shipped 14 Jul 2024 · № 023"
    end
    assert_select ".machines a.mach", count: 1
    assert_select ".machines", text: /#{ships(:drafted).title}/, count: 0
  end

  test "an app card's art is its preview, or its number when it has none" do
    get "/apps/"
    assert_select "#ship_#{ships(:cc).id} .art .no", text: "№ 023"

    ships(:cc).preview.attach(io: StringIO.new("mp4".b), filename: "loop.mp4", content_type: "video/mp4")
    get "/apps/"
    assert_select "#ship_#{ships(:cc).id} .art video[autoplay][muted][loop][playsinline][src=?]", ships(:cc).preview_path
  end

  test "skills and parts are the tools that live on GitHub, each pointing at its log entry" do
    get "/apps/"
    assert_select "#tools h2", text: "Skills & parts."
    assert_select "#tools + .essay-list a", count: 1
    assert_select "#tools + .essay-list a[href=?]", "/#ship_#{ships(:phone).id}" do
      assert_select ".mono", text: "№ 019"
      assert_select "h4", text: ships(:phone).title
    end
    assert_select "#tools + .essay-list", text: /#{ships(:clock).title}/, count: 0
  end

  test "the tools shelf is the second half of the apps page" do
    get "/tools/"
    assert_response :moved_permanently
    assert_redirected_to "/apps/#tools"
    get "/tools"
    assert_redirected_to "/apps/#tools"
  end

  test "the explorables page deals each explorable as a deck that opens it" do
    get "/explorables/"
    assert_response :success
    assert_select ".ph .kick", text: "Explorables · 1 deck"
    assert_select ".decks a.deck[href=?]", "https://nityesh.com/hotwire/" do
      assert_select ".card", count: 3
      assert_select ".card h4", text: "Hotwire, explored."
      assert_select ".card .foot span", text: "Deck · № 020"
      assert_select ".card .foot span", text: "9 Sep 2026"
    end
    assert_select ".decks a.deck", count: 1
  end

  test "the comics page deals each comic as a deck" do
    get "/comics/"
    assert_response :success
    assert_select ".ph .kick", text: "Comics · 1 comic · drawn with image models"
    assert_select ".decks a.deck[href=?]", ships(:markdown).check_it_out_url do
      assert_select ".card h4", text: ships(:markdown).title
      assert_select ".card .foot span", text: "Comic · № 001"
    end
    assert_select ".decks a.deck", count: 1
  end

  test "the essays page lists the current era's articles, then the drafts in the typewriter" do
    get "/essays/"
    assert_response :success
    assert_select ".ph .kick", text: "The library · 1 essay · 2 eras"
    assert_select ".essays .shelf-head h2", text: tags(:chronicles).name
    assert_select ".essays .shelf-head .mono", text: "2021–2023 · the current era"
    assert_select "#current a[href=?]", "/a-published-post/" do
      assert_select "h4", text: posts(:published).title
      assert_select "p", text: posts(:published).excerpt
      assert_select ".mono", text: posts(:published).published_at.strftime("%-d %b %Y")
    end
    assert_select "#current a", count: 1

    assert_select "#typewriter span.rise", count: 1 do
      assert_select ".mono", text: "Draft"
      assert_select "h4", text: posts(:promised).title
      assert_select "p", text: posts(:promised).excerpt
    end
    assert_select "#typewriter a", count: 0
  end

  # A draft is announced by its excerpt; the rest stay private. A published article is
  # never a draft, and a scheduled one is already on its way.
  test "only drafts with an excerpt and no publish stamp reach the typewriter" do
    get "/essays/"
    assert_select "#typewriter", text: /#{posts(:draft).title}/, count: 0
    assert_select "#typewriter", text: /#{posts(:scheduled).title}/, count: 0
    assert_select "#current", text: /#{posts(:promised).title}/, count: 0
  end

  test "the earlier eras link their archives with years and counts" do
    get "/essays/"
    assert_select ".eras a.era[href=?]", "/tag/past-life/", text: /past life\s+2017–2019 · 0/
    assert_select ".eras a.era", count: 1
    assert_select ".essays .aside", text: "Every URL from the Ghost years still resolves."
  end

  test "the masthead underlines the shelf it is on" do
    { "/apps/" => "Apps", "/explorables/" => "Explorables", "/comics/" => "Comics", "/essays/" => "Essays", "/about/" => "About" }.each do |path, label|
      get path
      assert_select ".nav a.on", count: 1
      assert_select ".nav a.on", text: label
    end
  end

  test "the shelves carry the subscribe envelope and their own titles" do
    get "/apps/"
    assert_select "section#subscribe .env form.sub-form"
    assert_select "title", text: "Apps — Nityesh Agarwal"
    get "/essays/"
    assert_select "title", text: "Essays — Nityesh Agarwal"
  end

  test "a bare shelf path 301s to the trailing-slash form" do
    get "/apps"
    assert_redirected_to "/apps/"
  end

  test "the shelves are ETagged" do
    get "/apps/"
    etag = response.headers["ETag"]
    assert etag.present?
    get "/apps/", headers: { "If-None-Match" => etag }
    assert_response :not_modified
  end

  # The shelves live at the root beside the posts, so their names can't be a post's slug.
  test "a shelf's name is reserved, not available to a post" do
    %w[ apps tools explorables comics essays ].each do |name|
      assert_equal :reserved, Slug.new(name).state, name
    end
  end

  test "the pages sitemap lists the shelves" do
    get sitemap_pages_url
    doc = Nokogiri::XML(response.body)
    doc.remove_namespaces!
    locs = doc.xpath("//url/loc").map(&:text)
    %w[ apps explorables comics essays ].each do |shelf|
      assert_includes locs, "http://www.example.com/#{shelf}/"
    end
  end
end
