require "test_helper"

# A pane can hold words instead of a query (ADR 039, #58). A stored frame
# rendered frame.panes and nothing else, and a pane had to name a measure,
# so the analyst who owns a frame could choose every number on it and label
# none of them. What an analyst writes is escaped; anything with markup is a
# partial the host wrote under app/views/janela_content/.
class ContentPaneTest < ActionDispatch::IntegrationTest
  setup { @frame = janela_frames(:orders) }

  test "a text pane needs no model or measure, and a query pane still does" do
    assert @frame.panes.build(kind: "text", heading: "Where the money is going").valid?

    query = @frame.panes.build(kind: "query")
    assert_not query.valid?
    assert query.errors[:measure].any?
  end

  test "a text pane says something" do
    pane = @frame.panes.build(kind: "text")

    assert_not pane.valid?
    assert pane.errors[:heading].any?
  end

  test "a content pane cannot also name a query" do
    pane = @frame.panes.build(kind: "text", heading: "Hi", model: "orders", measure: "revenue")

    assert_not pane.valid?
    assert pane.errors[:measure].any?
  end

  # A path keeps an analyst's link on the host's own site. A scheme, or a
  # protocol relative //, would send a reader anywhere under the host's name.
  test "a link is a path on this site and nothing else" do
    [ "/orders", "/orders?q[status_eq]=paid" ].each do |link|
      assert @frame.panes.build(kind: "text", heading: "Hi", link: link).valid?, link
    end
    [ "https://example.com", "//example.com", "javascript:alert(1)", "orders" ].each do |link|
      assert_not @frame.panes.build(kind: "text", heading: "Hi", link: link).valid?, link
    end
  end

  test "a partial pane names a partial the host wrote, and only such a partial" do
    assert @frame.panes.build(kind: "partial", partial: "overview_heading", heading: "Hi").valid?

    [ "missing", "../janela/panes/form", "Overview", "" ].each do |name|
      assert_not @frame.panes.build(kind: "partial", partial: name).valid?, name.inspect
    end
  end

  test "an unknown kind is refused" do
    assert_not @frame.panes.build(kind: "html", heading: "Hi").valid?
  end

  test "a stored frame renders its words beside its numbers, escaped" do
    @frame.panes.create!(kind: "text", heading: "Refunds <em>excluded</em>",
                         body: "First paragraph.\n\n<script>alert(1)</script>", link: "/orders", span: 3)

    get frame_path(@frame)

    assert_response :success
    assert_select ".janela-frame > .janela-span-3 > .janela-pane.janela-content" do
      assert_select "h2 a[href='/orders']", "Refunds <em>excluded</em>"
      assert_select "p", 2
      assert_select "p", "<script>alert(1)</script>"
      assert_select "script", false
      assert_select "em", false
    end
    assert_select ".janela-value-number", "$375.00"
  end

  test "a partial pane renders the host's partial with the analyst's words" do
    @frame.panes.create!(kind: "partial", partial: "overview_heading", heading: "Project <b>overview</b>")

    get frame_path(@frame)

    assert_select ".janela-content .demo-overview-heading svg[aria-hidden=true]"
    assert_select ".janela-content .demo-overview-heading h2", "Project <b>overview</b>"
  end

  # A partial showing a figure has to know which rows it is about. It was
  # handed only the analyst's words, so a host read its own page's instance
  # variables instead, and the partial broke on any other page (#60).
  test "a partial pane sees its frame, its row and the host's fixed filter" do
    pane = @frame.panes.create!(kind: "partial", partial: "scope_note")

    get frame_for_status_path(@frame, "paid")

    assert_select ".demo-scope-note[data-frame='#{@frame.id}'][data-pane='#{pane.id}']", text: /Acme's orders,\s+only paid\./
  end

  test "a partial pane on a frame with nothing fixed is handed an empty filter" do
    @frame.panes.create!(kind: "partial", partial: "scope_note")

    get frame_path(@frame)

    assert_select ".demo-scope-note", text: /Acme's orders\./
  end

  # A content pane is not a query, so it has no URL of its own to be fetched
  # from and is not something the frame controller refreshes.
  test "a content pane is not a turbo frame and has no pane URL" do
    pane = @frame.panes.create!(kind: "text", heading: "Hi")

    get frame_path(@frame)
    assert_select "turbo-frame#janela_pane_#{pane.id}", false
    assert_select "div#janela_pane_#{pane.id} .janela-content"

    get janela.frame_pane_path(@frame, pane)
    assert_response :not_found
  end

  test "an analyst adds a text pane from the engine's own pages" do
    get janela.new_frame_pane_path(@frame)
    assert_select "option[value=text]"
    assert_select "option[value='partial:overview_heading']"

    get janela.new_frame_pane_path(@frame, model: "text")
    assert_select "textarea[name='pane[body]']"

    assert_difference -> { @frame.panes.count }, 1 do
      post janela.frame_panes_path(@frame), params: { pane: { kind: "text", heading: "Read me", body: "Words.", span: 2 } }
    end
    assert_redirected_to janela.edit_frame_path(@frame)

    follow_redirect!
    assert_select ".janela-list-name", "Read me"

    pane = @frame.panes.last
    get janela.edit_frame_pane_path(@frame, pane)
    assert_response :success
    assert_select "input[name='pane[heading]'][value='Read me']"
  end
end
