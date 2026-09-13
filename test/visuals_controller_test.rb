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

  test "a model that has not declared a janela block is not addressable" do
    assert_raises(Janela::Error) do
      get janela.visual_path(model: "Customer", measure: "revenue", by: "status")
    end
  end
end
