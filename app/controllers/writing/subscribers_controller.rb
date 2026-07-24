class Writing::SubscribersController < Writing::BaseController
  layout "writing"

  def index
    @subscribers = Subscriber.order(created_at: :desc)
  end
end
