require "test_helper"

# #103. A pane sets aside the reader's filter on its own dimension, which is
# the cross-filtering rule (ADR 003). Believed: a key that starts with the
# pane's own dimension's name is that dimension's. Measured: store_type_in
# starts with store, so a pane by store set a store type click aside and drew
# every store, unfiltered, with no error.
class OwnDimensionKeyTest < ActiveSupport::TestCase
  setup do
    ActiveRecord::Base.connection.create_table(:store_probes, force: true) { |t| t.string :store; t.string :store_type }
    @probe = Class.new(ActiveRecord::Base) do
      def self.name = "StoreProbe"
      self.table_name = "store_probes"
      janela do
        measure :visits, count: true
        dimension :store
        dimension :store_type
      end
    end
    @probe.create!(store: "North", store_type: "metro")
    @probe.create!(store: "South", store_type: "country")
  end

  teardown do
    ActiveRecord::Base.connection.drop_table(:store_probes, if_exists: true)
    Janela.registry.delete("store_probes")
  end

  def by(dimension, filters)
    Janela::Query.new(definition: @probe.janela, measure: :visits, dimension: dimension, filters: filters).result(on: @probe.all)
  end

  test "a pane by store is narrowed by a click on store type" do
    assert_equal({ "North" => 1 }, by(:store, { "store_type_in" => [ "metro" ] }))
  end

  test "a pane by store still sets aside a click on store itself" do
    assert_equal({ "North" => 1, "South" => 1 }, by(:store, { "store_in" => [ "North" ] }))
  end

  # A typo on the pane's own key used to be set aside with it; it is now
  # refused like a typo on any other key (ADR 025).
  test "a misspelt predicate on the pane's own dimension is refused" do
    assert_raises(Janela::BadRequest) { by(:store, { "store_inn" => [ "North" ] }) }
  end
end
