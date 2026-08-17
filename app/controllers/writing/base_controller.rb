class Writing::BaseController < ApplicationController
  include Writing::Autosaving

  # The editor (Lexxy rich text) is the only surface that genuinely needs modern browser
  # APIs, so the gate lives here — not on ApplicationController, where it 406'd public
  # readers on older browsers site-wide (invisible in Search Console, since crawlers send
  # no version). Only allow modern browsers supporting webp images, web push, badges,
  # import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
end
