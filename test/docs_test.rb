require "test_helper"

# The demo renders Janela's own documentation from the markdown that ships in
# the gem, so these are the pages a stranger reads first.
class DocsTest < ActionDispatch::IntegrationTest
  test "the documentation index lists the guides and every decision" do
    get docs_path

    assert_response :success
    assert_select "a[href=?]", doc_path("multi-tenancy")
    assert_select "a[href=?]", doc_path("composing")
    assert_select "a[href=?]", doc_path("024-selecting-more-than-one-value")
  end

  # The naming guide is told at /name, linked from the top nav, so listing it
  # under Documentation as well said the same thing twice.
  test "the naming guide is not listed as a document, and its old URL lands on /name" do
    get docs_path

    assert_response :success
    assert_select "a[href=?]", "/docs/naming", count: 0
    assert_select ".shell-nav a", text: "Naming Things Is Hard", count: 0

    get "/docs/naming"
    assert_redirected_to the_name_path
  end

  test "a decision renders from the file that ships in the gem" do
    get doc_path("024-selecting-more-than-one-value")

    assert_response :success
    assert_select "h1", "Selecting More Than One Value"
    assert_select ".doc-status", "Accepted"
  end

  # A slug is looked up in a catalogue built from the docs directory, never
  # joined onto a path, so a request cannot name a file of its own choosing.
  test "a slug that is not a document is a 404, not a file read" do
    get "/docs/does-not-exist"
    assert_response :not_found

    get "/docs/INDEX"
    assert_response :not_found
  end

  test "the name page tells the story on top of the naming guide" do
    get the_name_path

    assert_response :success
    assert_select ".anatomy-term", count: 5
    assert_select ".doc-prose h2", text: "The rule"
  end
end
