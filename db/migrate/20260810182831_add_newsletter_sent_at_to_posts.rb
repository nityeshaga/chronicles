class AddNewsletterSentAtToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :newsletter_sent_at, :datetime
  end
end
