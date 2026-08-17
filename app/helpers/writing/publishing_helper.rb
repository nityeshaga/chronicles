module Writing::PublishingHelper
  # The zone the writer's publish times are in, read off the app's own zone rather than
  # typed — "IST, UTC+5:30" here, and whatever the next deployer set anywhere else.
  def publish_zone_label
    "#{Time.zone.now.strftime("%Z")}, UTC#{Time.zone.formatted_offset.sub(/\A([+-])0/, '\1')}"
  end

  # Every publish time the writer reads — in the popover and on the dashboard row —
  # carries its zone, because a schedule without one is a guess he has to make at the
  # only moment it matters.
  def publish_stamp(time)
    time.strftime("%-d %b %Y, %-l:%M %p %Z")
  end

  # What a datetime-local field will accept as the earliest time, in the shape the
  # control wants and in the app's zone — the browser reads the string with no offset
  # and means local, which is the same clock the label names.
  def publish_time_floor
    Time.zone.now.strftime("%Y-%m-%dT%H:%M")
  end
end
