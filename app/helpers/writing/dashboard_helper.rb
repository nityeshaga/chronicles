module Writing::DashboardHelper
  # Every tab of the writing dashboard: the bucket it filters the one list down to, its
  # label, and the axis it reads down. Scheduled is the only tab that asks "what goes live
  # next" instead of "what did I touch last", and this table is the whole of that
  # difference — it rides onto each button as data, so the Stimulus controller sorts by
  # whatever the pressed tab tells it to and never knows a tab by name.
  TABS = [
    { bucket: "all", label: "All" },
    { bucket: "draft", label: "Drafts" },
    { bucket: "scheduled", label: "Scheduled", sort: "goes-live", direction: 1 },
    { bucket: "published", label: "Published" },
    { bucket: "page", label: "Pages" },
    { bucket: "html_page", label: "HTML pages" }
  ].freeze

  def dashboard_tabs(records)
    # Counts are a tally of the list on screen, never a second query that could disagree
    # with it. "All" is every record by definition, which is why it isn't a bucket.
    counts = records.map(&:dashboard_bucket).tally
    counts["all"] = records.size

    TABS.map { |tab| { sort: "edited", direction: -1, count: counts[tab[:bucket]].to_i }.merge(tab) }
  end
end
