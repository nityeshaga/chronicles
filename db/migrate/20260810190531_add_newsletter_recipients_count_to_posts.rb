class AddNewsletterRecipientsCountToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :newsletter_recipients_count, :integer
  end
end
