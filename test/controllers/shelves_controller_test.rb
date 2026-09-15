require "test_helper"

# The shelves: one page per kind of thing in the log, and the essays by era. Each reads
# the same published ships the homepage does, so a draft never reaches a shelf either.
class ShelvesControllerTest < ActionDispatch::IntegrationTest
  test "the apps page is the workbench: every app ship as a card" do
    get "/apps/"
    assert_response :success
    assert_select ".ph .kick", text: "The Workbench"
    assert_select ".ph h1", text: "1 software tool I built for myself"
    assert_select ".ph p", count: 0
    assert_select "#tools", count: 0
    assert_select ".machines a.mach[href=?]", "https://curatedconnections.io" do
      assert_select ".meta h4", text: "Curated Connections."
      assert_select ".meta p", text: "Self-driving community software."
      assert_select ".meta .mono", text: "Shipped 14 Jul 2024"
    end
    assert_select ".machines a.mach", count: 1
    assert_select ".machines", text: /#{ships(:drafted).title}/, count: 0
    assert_select ".machines", text: /#{ships(:phone).title}/, count: 0
  end

  test "an app card's art is its preview, or its kind when it has none" do
    get "/apps/"
    assert_select "#ship_#{ships(:cc).id} .art .no", text: "App"

    ships(:cc).preview.attach(io: StringIO.new("mp4".b), filename: "loop.mp4", content_type: "video/mp4")
    get "/apps/"
    assert_select "#ship_#{ships(:cc).id} .art video[muted][loop][playsinline][preload=none][data-controller=lazy-video][data-src=?]", ships(:cc).preview_path
  end

  test "/tools goes to the apps page" do
    get "/tools/"
    assert_response :moved_permanently
    assert_redirected_to "/apps/"
    get "/tools"
    assert_redirected_to "/apps/"
  end

  test "the explorables page stacks each explorable with its front page as the picture" do
    ships(:hotwire).preview.attach(io: StringIO.new("jpg".b), filename: "shot-hotwire.jpg", content_type: "image/jpeg")
    get "/explorables/"
    assert_response :success
    assert_select ".ph .kick", text: "Explorables · 1 deck"
    assert_select ".rows a.row[href=?]", "https://nityesh.com/hotwire/" do
      assert_select ".art img[src=?]", ships(:hotwire).preview_path
      assert_select ".meta h4", text: "Hotwire, explored."
      assert_select ".meta .mono", text: "Explorable · 9 Sep 2026"
    end
    assert_select ".rows a.row", count: 1
  end

  test "the comics page stacks each comic with its first page as the picture" do
    ships(:markdown).preview.attach(io: StringIO.new("jpg".b), filename: "page-1.jpg", content_type: "image/jpeg")
    get "/comics/"
    assert_response :success
    assert_select ".ph .kick", text: "Comics · 1 comic · drawn with image models"
    assert_select ".rows a.row[href=?]", ships(:markdown).check_it_out_url do
      assert_select ".art img[src=?]", ships(:markdown).preview_path
      assert_select ".meta h4", text: ships(:markdown).title
      assert_select ".meta .mono", text: /Comic/
    end
    assert_select ".rows a.row", count: 1
  end

  test "the essays page lists the current era's articles, then the earlier eras beneath" do
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
    assert_select "#typewriter", count: 0
    assert_select ".essays", text: /#{posts(:promised).title}/, count: 0
    assert_select "#current ~ .shelf-head.earlier h2", text: "Earlier eras"
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
