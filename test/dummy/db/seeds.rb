# Deterministic demo data: a year of orders for a handful of customers, plus
# one snapshot taken at quarter end so the published view has something to show.
if Order.none?
  random = Random.new(2026)
  customers = {
    "APAC" => [ "Acme", "Kaito Foods", "Southern Cross" ],
    "EU" => [ "Globex", "Nordwind" ],
    "Americas" => [ "Initech", "Vandelay Imports" ]
  }.flat_map { |region, names| names.map { |name| Customer.create!(name: name, region: region) } }

  statuses = %w[paid] * 14 + %w[pending] * 3 + %w[refunded] * 2 + %w[cancelled]
  first_day = Date.new(2025, 9, 1)

  600.times do
    Order.create!(
      customer: customers[random.rand(customers.size)],
      status: statuses[random.rand(statuses.size)],
      amount: (random.rand(20.0..900.0) * (1 + random.rand(3))).round(2),
      placed_on: first_day + random.rand(379)
    )
  end

  Janela::Snapshot.take(name: "Q3 2026 close", filters: { status_eq: "paid" }, taken_at: Time.utc(2026, 9, 30, 23, 59)) do |take|
    take.pane Order, :revenue
    take.pane Order, :orders
    take.pane Order, :revenue, by: :status
    take.pane Order, :revenue, by: :region
    take.pane Order, :revenue, by: :customer, limit: 5
    take.pane Order, :revenue, by: :placed_on, granularity: :month
  end
end

# The same dashboard again, composed as rows rather than ERB, so the demo shows
# both ways of supplying panes (ADR 012). Each frame belongs to a customer,
# which stands in for a tenant: the demo's policy_scope reads frames through
# that owner, so Janela's own index shows one frame here and a different one
# under ?tenant=.
if Janela::Frame.none?
  frame = Janela::Frame.create!(name: "Orders, from the database", columns: 3, gap: 4,
                                owner: Customer.order(:name).first)
  [
    { model: "orders", measure: "revenue" },
    { model: "orders", measure: "orders" },
    { model: "orders", measure: "average_order", title: "Average basket" },
    { model: "orders", measure: "revenue", dimension: "placed_on", renderer: "line", granularity: "month", span: 3 },
    { model: "orders", measure: "revenue", dimension: "status", renderer: "bar", span: 2 },
    { model: "orders", measure: "revenue", dimension: "region" },
    { model: "orders", measure: "revenue", dimension: "customer", limit: 5, title: "Top five customers" },
    { model: "orders", measure: "orders", dimension: "region" }
  ].each { |row| frame.panes.create!(**row) }

  other = Janela::Frame.create!(name: "A second tenant's dashboard", columns: 2, gap: 4,
                                owner: Customer.order(:name).offset(1).first)
  [
    { model: "orders", measure: "revenue" },
    { model: "orders", measure: "revenue", dimension: "status", renderer: "bar", span: 2 },
    { model: "orders", measure: "orders", dimension: "region" }
  ].each { |row| other.panes.create!(**row) }
end
