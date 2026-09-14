require "test_helper"

class VisualsControllerTest < ActionDispatch::IntegrationTest
  test "renders a measure grouped by a dimension" do
    get janela.visual_path(model: "Order", measure: "revenue", by: "status")

    assert_response :success
    assert_select "td", "paid"
    assert_select "td", "300.0"
  end

  test "a filter on another dimension scopes the visual" do
    get janela.visual_path(model: "Order", measure: "revenue", by: "status", q: { customer_region_eq: "APAC" })

    assert_response :success
    assert_select "td", "100.0"
    assert_select "td", text: "300.0", count: 0
  end

  test "a visual ignores a filter on its own dimension" do
    get janela.visual_path(model: "Order", measure: "revenue", by: "status", q: { status_eq: "paid" })

    assert_response :success
    assert_select "td", "refunded"
  end

  test "values carry the filter key the dashboard controller sends back" do
    get janela.visual_path(model: "Order", measure: "revenue", by: "region")

    assert_select "button[data-janela--dashboard-key-param=?]", "customer_region_eq"
  end

  test "a scalar q parameter is ignored rather than raising" do
    get janela.visual_path(model: "Order", measure: "revenue", by: "status", q: "x")

    assert_response :success
    assert_select "td", "300.0"
  end

  test "the value selected on a visual's own dimension is marked pressed" do
    get janela.visual_path(model: "Order", measure: "revenue", by: "status", q: { status_eq: "paid" })

    assert_select "button[aria-pressed=true]", "paid"
    assert_select "button[aria-pressed=false]", "refunded"
  end

  test "a bar visual renders a canvas carrying its data and selection" do
    get janela.visual_path(model: "Order", measure: "revenue", by: "status", as: "bar", q: { status_eq: "paid" })

    assert_select "canvas[data-controller='janela--chart'][data-janela--chart-selected-value=paid]"
    assert_select "canvas[data-janela--chart-values-value='[300.0,25.0,50.0]']"
  end

  test "a visual with no rows renders an empty state" do
    get janela.visual_path(model: "Order", measure: "revenue", by: "status", q: { customer_region_eq: "Mars" })

    assert_select "p.janela-empty"
  end

  test "an unknown renderer raises" do
    assert_raises(Janela::Error) do
      get janela.visual_path(model: "Order", measure: "revenue", by: "status", as: "pie")
    end
  end

  test "a model that has not declared a janela block is not addressable" do
    assert_raises(Janela::Error) do
      get janela.visual_path(model: "Customer", measure: "revenue", by: "status")
    end
  end
end
