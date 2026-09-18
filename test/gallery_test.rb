require "test_helper"

# The reference page ADR 027 says a gallery is: a host page, built from
# Janela.renderers, Janela.granularities, Janela.offered_limits and
# Janela.definitions rather than from Janela::Query::RENDERERS or any other
# constant reached into directly (#39).
class GalleryTest < ActionDispatch::IntegrationTest
  test "every renderer is drawn against the demo's own data, with its declaration beside it" do
    get gallery_path

    assert_response :success
    # Sectioned by the kind of visualisation, so the heading is the renderer
    # and the model is one demonstration under it (ADR 027's gallery, laid out
    # the way a reader looking for "what does a bar chart look like" reads).
    assert_select "h2", "Table"
    assert_select "h2", "Bar chart"
    assert_select "h2", "Line chart"
    assert_select "h3", "Order"
    assert_select "code.gallery-declaration", "janela_pane Order, :revenue"
    assert_select "code.gallery-declaration", "janela_pane Order, :revenue, by: :status, as: :bar"
    assert_select "code.gallery-declaration", "janela_pane Order, :revenue, by: :placed_on, as: :line, granularity: :month"
    assert_select "p.janela-muted", count: 0
  end

  # A model that declares no measure cannot demonstrate any renderer, since
  # every Janela query needs one: shown as unavailable, not hidden, because a
  # gap a gallery hides is a gap nobody notices (ADR 026's reasoning about a
  # renderer that does not exist yet, applied to a model that cannot show one).
  test "a renderer a model cannot demonstrate is shown as unavailable, not hidden" do
    # Janela.definitions resolves the registry through safe_constantize, so an
    # anonymous class with an overridden .name would not be found by it, and
    # naming it before it declares the block matters too: janela registers
    # under model_name.route_key, which is nil until the class has a name.
    klass = Object.const_set(:EmptyOrder, Class.new(Order))
    klass.janela { }

    get gallery_path

    assert_select "h3", "Empty order"
    assert_select "p.janela-muted", text: "Not shown: EmptyOrder declares no measure.", count: 3
  ensure
    Janela.registry.delete("empty_orders")
    Object.send(:remove_const, :EmptyOrder)
  end

  # A host that has not put a janela block on any model yet still gets a page
  # that says something useful rather than a blank one (ADR 027's other owed
  # answer).
  test "a host with no janela models yet is told why the page is empty" do
    registry = Janela.registry.dup
    Janela.registry.clear

    get gallery_path

    assert_response :success
    assert_select ".janela-empty", /nothing to draw/
  ensure
    Janela.registry.replace(registry)
  end
end
