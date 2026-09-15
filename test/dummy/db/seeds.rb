# Deterministic demo data: a year of orders for a handful of customers, plus
# one snapshot taken at quarter end so the published view has something to show.
return if Order.exists?

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
