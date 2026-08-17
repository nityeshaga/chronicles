module Writing::PublishingHelper
  # The zone the writer's publish times are in, read off the app's own zone rather than
  # typed — "IST, UTC+5:30" here, and whatever the next deployer set anywhere else.
  def publish_zone_label
    "#{Time.zone.now.strftime("%Z")}, UTC#{Time.zone.formatted_offset.sub(/\A([+-])0/, '\1')}"
  end

  # Every time the writer reads on the publishing surfaces — the popover, the dashboard
  # row — carries its zone, because a stamp without one is a guess he has to make at the
  # only moment it matters.
  def zoned_stamp(time)
    time.strftime("%-d %b %Y, %-l:%M %p %Z")
  end

  # What a datetime-local field will accept as the earliest time, in the shape the
  # control wants and in the app's zone — the browser reads the string with no offset
  # and means local, which is the same clock the label names.
  def publish_time_floor
    Time.zone.now.strftime("%Y-%m-%dT%H:%M")
  end

  # Whether this editor was arrived at from a publishing action, and so should open with
  # the popover already up. A one-shot flash rather than a query param: the answer is
  # true of this arrival only, and a param would make every Back and Turbo restore
  # reopen a panel the writer already dismissed.
  def publishing_open? = flash[:publishing] == "open"
end
