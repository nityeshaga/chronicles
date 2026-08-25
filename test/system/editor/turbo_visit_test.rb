require "editor_system_test_case"

# The editor arrives by Turbo far more often than by a page load — every click out of the
# dashboard is one — and a Turbo visit hands the document the whole new body in a single
# insertion. Custom elements upgrade parent before child there, so this is the one path
# where <lexxy-editor> can reach for its <lexxy-toolbar> before the toolbar is a Lexxy
# element at all. A page load never reproduces it, which is how it reached production.
class TurboVisitTest < EditorSystemTestCase
  test "an editor reached from the dashboard mounts, with its toolbar bound" do
    sign_in_as users(:nityesh)
    post = posts(:published)
    assert_selector ".dash-list"

    # A page load would clear this; surviving the click is what says Turbo drove the
    # visit, so the assertions below are about the path this test exists for.
    page.execute_script("window.arrivedByTurbo = true")
    find(".dash-row__link", text: post.title).click

    assert_selector "lexxy-editor[connected] .lexxy-editor__content", text: "The body of a published post."
    assert_selector "lexxy-toolbar[connected]"
    assert page.evaluate_script("window.arrivedByTurbo === true"), "the click reloaded the page instead of visiting"
  end
end
