# The first 23 ships, from db/seeds/ships.yml, with their media from a directory on disk.
#
#   bin/rails ships:backfill MEDIA_DIR=/path/to/media
#
# Idempotent: a ship is found by its number, so a re-run updates the fields, links a post
# that has since appeared, attaches media that was missing, and never mints a second copy.
# Media already attached is left alone unless REPLACE_MEDIA=1, which re-attaches every
# preview and poster named in the seeds — the way to roll out a better encode.
namespace :ships do
  desc "Create and publish the first 23 ships from db/seeds/ships.yml, attaching media from MEDIA_DIR"
  task backfill: :environment do
    media_dir = Pathname(ENV.fetch("MEDIA_DIR", "/Users/luo/work/nityesh-com-v2/media"))
    entries = YAML.load_file(Rails.root.join("db/seeds/ships.yml"))

    entries.each do |entry|
      ship = Ship.find_or_initialize_by(number: entry["number"])
      ship.assign_attributes(entry.slice("shipped_on", "kind", "built_by", "title", "blurb", "check_it_out_url", "prompt", "x_status_id"))

      if entry["post"]
        ship.post = Post.find_by(slug: entry["post"])
        warn "No. #{entry["number"]}: no post with slug #{entry["post"]} yet — left unlinked" unless ship.post
      end

      ship.save!
      replace = ENV["REPLACE_MEDIA"] == "1"
      attach(ship.preview, media_dir.join(entry["preview"])) if entry["preview"] && (replace || !ship.preview.attached?)
      attach(ship.poster, media_dir.join(entry["poster"])) if entry["poster"] && (replace || !ship.poster.attached?)
      ship.publish if ship.draft?

      puts format("No. %03d  %-10s  %-8s  %s", ship.number, ship.kind, ship.media_kind, ship.title)
    end

    ships = Ship.where(number: entries.map { |e| e["number"] })
    puts "#{ships.count} ships, #{ships.published.count} published; " \
         "#{ships.count { |s| s.media_kind == :video }} video, " \
         "#{ships.count { |s| s.media_kind == :image }} image, " \
         "#{ships.count { |s| s.media_kind == :cover }} cover, " \
         "#{ships.count { |s| s.post }} linked to a post"
  end

  def attach(attachment, path)
    raise "missing media file #{path}" unless path.exist?

    attachment.attach(io: path.open, filename: path.basename.to_s, content_type: Marcel::MimeType.for(path))
  end
end
