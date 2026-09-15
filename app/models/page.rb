class Page < Post
  def og_type = "website"
  def body_class = "page-template"
  def article_meta? = false
  def show_title? = false
  def newsletterable? = false
  def dashboard_bucket = "page"
  def taggable? = false

  # The box beside the prose: the house, by the numbers. Read fresh on every render and
  # folded into the page's ETag, because a ship logged tonight changes this page without
  # anyone touching the page.
  def house_numbers
    {
      ships: Ship.log.count,
      apps: Ship.log.app.count,
      explorables: Ship.log.explorable.count,
      essays: Post.articles.published.count,
      eras: Tag.eras.size,
      lines: Page.lines_of_rails
    }
  end

  # Counted once per process: the code doesn't change under a running app.
  def self.lines_of_rails
    @lines_of_rails ||= Rails.root.glob("app/**/*.{rb,erb}").sum { |file| file.read.count("\n") }
  end
end
