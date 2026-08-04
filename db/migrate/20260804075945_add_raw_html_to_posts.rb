class AddRawHtmlToPosts < ActiveRecord::Migration[8.1]
  # The body of an HtmlPage: one complete, hand-authored HTML document served
  # verbatim at a root slug. Nullable because only that STI kind uses it — posts
  # and pages keep writing their body through Action Text, untouched.
  def change
    add_column :posts, :raw_html, :text
  end
end
