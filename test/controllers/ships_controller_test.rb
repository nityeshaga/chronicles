require "test_helper"

# The homepage is the ship log: everything published, newest first, each with its
# number, its kind, its media and its doors.
class ShipsControllerTest < ActionDispatch::IntegrationTest
  test "the log lists published ships newest-first with their numbers, and no drafts" do
    get root_url
    assert_response :success
    assert_equal [ "ship_#{ships(:phone).id}", "ship_#{ships(:essay).id}" ], css_select("article.ship").map { |a| a["id"] }
    assert_select "article.ship .when .no", text: "№ 019"
    assert_select "article.ship .when .no", text: "№ 016"
    assert_select "article.ship h3 a", text: ships(:drafted).title, count: 0
  end

  test "ships sit under the month they shipped in" do
    get root_url
    assert_select ".month h2", text: "Sep 2026"
    assert_select ".month h2", text: "Aug 2026"
    assert_select ".month .count", text: "1 thing", count: 2
  end

  test "a ship wears its kind and links its title to where it lives" do
    get root_url
    assert_select "article.ship.k-tool .kind", text: "Tool"
    assert_select "article.ship h3 a[href=?]", ships(:phone).check_it_out_url, text: ships(:phone).title
  end

  test "a video ship plays its trim over a poster, framed by a link to the X post" do
    ship = ships(:phone)
    ship.preview.attach(io: StringIO.new("mp4".b), filename: "loop.mp4", content_type: "video/mp4")
    ship.poster.attach(io: StringIO.new("jpg".b), filename: "poster.jpg", content_type: "image/jpeg")

    get root_url
    assert_select "a.frame[href=?]", "https://x.com/nityeshaga/status/2098484853939597670" do
      assert_select "video[autoplay][muted][loop][playsinline][src=?][poster=?]", ship.preview_path, ship.poster_path
      assert_select ".watch", text: "Watch the full one on X"
    end
  end

  test "a ship that announces something on this site frames a screenshot that opens it" do
    ship = ships(:essay)
    ship.preview.attach(io: StringIO.new("\x89PNG".b), filename: "shot.png", content_type: "image/png")

    get root_url
    assert_select "a.frame[href=?]", ship.check_it_out_url do
      assert_select "img.media.shot[src=?]", ship.preview_path
      assert_select ".watch", text: "Open it"
    end
  end

  test "a ship with no preview of its own frames the linked post's feature image" do
    get root_url
    assert_select "a.frame[href=?]", ships(:essay).check_it_out_url do
      assert_select "img.media.cover[src=?]", posts(:published).feature_image
    end
  end

  test "a ship with no media has no frame" do
    get root_url
    assert_select "#ship_#{ships(:phone).id} .frame", count: 0
  end

  test "the copy-prompt door appears only when there is a prompt" do
    get root_url
    assert_select "#ship_#{ships(:phone).id} button.door.copy"
    assert_select "#ship_#{ships(:phone).id} [data-clipboard-target=source]", text: ships(:phone).prompt
    assert_select "#ship_#{ships(:essay).id} button.door.copy", count: 0
  end

  test "the how-I-built-this door is dashed until the post exists, then opens it" do
    get root_url
    assert_select "#ship_#{ships(:phone).id} .door.empty", text: "How I built this"

    ships(:phone).update!(how_built_post: posts(:published))
    get root_url
    assert_select "#ship_#{ships(:phone).id} .door.empty", count: 0
    assert_select "#ship_#{ships(:phone).id} a.door[href=?]", "/#{posts(:published).slug}/", text: /How I built this/
  end

  # A chronicle is the writing; it has nothing to say about how it was built.
  test "a chronicle offers no how-I-built-this door" do
    get root_url
    assert_select "#ship_#{ships(:essay).id} .door.empty", count: 0
  end

  test "the by-line stamps who built it" do
    get root_url
    assert_select "#ship_#{ships(:phone).id} .by", text: /Built together/ do
      assert_select ".stamp.n", text: "N"
      assert_select ".stamp.l", text: "L"
    end
    assert_select "#ship_#{ships(:essay).id} .by", text: /Built by Nityesh/ do
      assert_select ".stamp.n", text: "N"
      assert_select ".stamp.l", count: 0
    end
  end

  test "the hero counts the days since the last ship and the apps running" do
    travel_to Time.zone.local(2026, 9, 15, 12) do
      get root_url
    end
    assert_select ".hero .stat .big", text: /4\s*days ago/
    assert_select ".hero .stat .big", text: /2\s*things/
    assert_select ".hero .stat .big", text: Machine.all.size.to_s
  end

  # The old masthead forbade nav links because they were in-page anchors dressed as
  # destinations. Now they are destinations — one page per kind — so the test flips:
  # the log's masthead names every shelf. (PR C fills the pages behind them.)
  test "the masthead nav names the shelves, X, and the email CTA" do
    get root_url
    assert_select ".nav a[href=?]", "/", text: "Latest"
    assert_select ".nav a.on", text: "Latest"
    %w[ /apps/ /apps/#tools /explorables/ /comics/ /essays/ /about/ ].each do |href|
      assert_select ".nav a[href=?]", href
    end
    assert_select ".nav a.xlink[href=?]", "https://x.com/nityeshaga"
    assert_select ".nav a.cta[href=?]", "/#subscribe"
  end

  test "the footer links the feed and the source" do
    get root_url
    assert_select ".foot a[href=?]", "/rss/"
    assert_select ".foot a[href=?]", "https://github.com/nityeshaga/chronicles"
  end

  test "the subscribe envelope carries the form" do
    get root_url
    assert_select "section#subscribe .env" do
      assert_select "#subscribe_form form.sub-form[action=?]", subscribers_path
      assert_select "input[type=email][name=email]"
    end
  end

  test "the homepage is ETagged, and a signup flash skips the conditional GET" do
    get root_url
    etag = response.headers["ETag"]
    assert etag.present?
    get root_url, headers: { "If-None-Match" => etag }
    assert_response :not_modified

    post subscribers_url, params: { email: "reader@example.com" }, headers: { "If-None-Match" => etag }
    follow_redirect!
    assert_response :success
    assert_select "#subscribe_form .confirm", text: "First class. You're on the list."
  end

  test "the article feed is still served at /rss" do
    get "/rss/"
    assert_response :success
    assert_equal "application/rss+xml", response.media_type
    assert_match posts(:published).title, response.body
  end
end
