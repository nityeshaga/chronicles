require "test_helper"

class ShipTest < ActiveSupport::TestCase
  test "the log is the published ships, newest first, same day by number" do
    older = Ship.create!(title: "Older", kind: "tool", built_by: "luo", shipped_on: "2026-09-11", number: 18, status: :published)

    assert_equal [ ships(:phone), older, ships(:essay) ], Ship.log.to_a
    assert_not_includes Ship.log, ships(:drafted)
  end

  test "by_month groups the log by the month it shipped" do
    months = Ship.by_month
    assert_equal [ Date.new(2026, 9, 1), Date.new(2026, 8, 1) ], months.keys
    assert_equal [ ships(:phone) ], months[Date.new(2026, 9, 1)]
  end

  test "publishing mints the next number and stamps the time" do
    ship = ships(:drafted)
    assert_nil ship.number

    ship.publish
    assert ship.published?
    assert_equal 20, ship.number
    assert_in_delta Time.current, ship.published_at, 5
  end

  test "publishing keeps a number already given" do
    ship = Ship.create!(title: "Backfilled", kind: "comic", built_by: "nityesh", shipped_on: "2026-04-27", number: 1)
    ship.publish
    assert_equal 1, ship.reload.number
  end

  test "a number is given once" do
    dup = Ship.new(title: "Twin", kind: "tool", built_by: "luo", shipped_on: "2026-09-11", number: 19)
    assert_not dup.valid?
    assert dup.errors[:number].any?
  end

  test "an unknown kind or builder is a validation error, not an exception" do
    ship = Ship.new(title: "Odd", kind: "gadget", built_by: "robot", shipped_on: "2026-09-11")
    assert_not ship.valid?
    assert ship.errors[:kind].any?
    assert ship.errors[:built_by].any?
  end

  test "check_it_out_url falls back to the linked post's public URL" do
    assert_equal "https://github.com/nityeshaga/claude-home-base", ships(:phone).check_it_out_url
    assert_equal "https://#{Setting.current.production_host}/a-published-post/", ships(:essay).check_it_out_url
    assert_nil ships(:drafted).check_it_out_url

    essay = ships(:essay)
    essay.update!(check_it_out_url: "https://elsewhere.example/x")
    assert_equal "https://elsewhere.example/x", essay.check_it_out_url
  end

  test "media_kind reads the preview's bytes, then the post's cover, then nothing" do
    assert_nil ships(:drafted).media_kind
    assert_equal :cover, ships(:essay).media_kind

    ship = ships(:phone)
    ship.preview.attach(io: StringIO.new("\x89PNG\r\n\x1a\n".b), filename: "still.png", content_type: "image/png")
    assert_equal :image, ship.media_kind

    ship.preview.attach(io: StringIO.new("mp4".b), filename: "loop.mp4", content_type: "video/mp4")
    assert_equal :video, ship.reload.media_kind
  end

  test "preview and poster URLs go through the proxy on the production host" do
    ship = ships(:phone)
    assert_nil ship.preview_url

    ship.preview.attach(io: StringIO.new("mp4".b), filename: "loop.mp4", content_type: "video/mp4")
    ship.poster.attach(io: StringIO.new("jpg".b), filename: "poster.jpg", content_type: "image/jpeg")

    proxy = %r{\Ahttps://#{Regexp.escape(Setting.current.production_host)}/rails/active_storage/blobs/proxy/}
    assert_match proxy, ship.preview_url
    assert_match proxy, ship.poster_url
    assert ship.preview_url.end_with?("/loop.mp4")
  end

  # The site default is the redirect route (upload_image's permanent URLs rely on it); a
  # <video> tag can't follow a 302 with a Range request, so ship media names the proxy.
  test "preview_path is the proxy route while the site default stays the redirect" do
    ship = ships(:phone)
    assert_nil ship.preview_path

    ship.preview.attach(io: StringIO.new("mp4".b), filename: "loop.mp4", content_type: "video/mp4")
    assert_match %r{\A/rails/active_storage/blobs/proxy/.*/loop\.mp4\z}, ship.preview_path
    assert_match %r{/blobs/redirect/}, Rails.application.routes.url_helpers.rails_blob_path(ship.preview, only_path: true)
  end

  # A post can go; the ship it announced stays in the log and simply loses its link.
  test "deleting a linked post unlinks the ship rather than taking it along" do
    posts(:published).destroy
    assert_nil ships(:essay).reload.post
    assert_nil ships(:essay).check_it_out_url
  end

  test "a ship needs a title, a date, a kind and a builder" do
    ship = Ship.new
    assert_not ship.valid?
    assert ship.errors[:title].any? && ship.errors[:shipped_on].any? && ship.errors[:kind].any? && ship.errors[:built_by].any?
  end
end
