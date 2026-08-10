require "test_helper"

class NewsletterMailerTest < ActionMailer::TestCase
  test "issue is addressed to the subscriber and carries the post" do
    mail = NewsletterMailer.issue(posts(:published), subscribers(:reader))

    assert_equal [ "reader@example.com" ], mail.to
    assert_equal "A Published Post", mail.subject
    assert_match "A Published Post", mail.body.encoded
  end

  test "issue carries a one-click unsubscribe header and footer link" do
    mail = NewsletterMailer.issue(posts(:published), subscribers(:reader))

    assert_equal "List-Unsubscribe=One-Click", mail["List-Unsubscribe-Post"].to_s
    assert_match %r{/unsubscribe/}, mail["List-Unsubscribe"].to_s
    assert_match %r{/unsubscribe/}, mail.body.encoded
  end
end
