module ShipsHelper
  # The by-line under the doors: who built it, in words, beside their stamps.
  def built_by_label(ship)
    ship.built_by_together? ? "Built together" : "Built by #{ship.built_by.capitalize}"
  end

  # Days since the newest ship — the hero's clock.
  def days_since(date)
    (Date.current - date).to_i
  end
end
