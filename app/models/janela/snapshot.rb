module Janela
  # A snapshot freezes the results of several panes at one instant under one
  # set of filters, so an audience sees exactly what was signed off while the
  # live dashboard stays editable (ADR 009). Results are stored, not HTML; the
  # renderer is chosen by whoever shows a stored pane.
  class Snapshot < ActiveRecord::Base
    attribute :filters, default: -> { {} }
    attribute :panes, default: -> { [] }

    validates :name, :taken_at, presence: true

    def self.take(name:, filters: {}, taken_at: Time.current)
      taking = Taking.new(filters.to_h.stringify_keys)
      yield taking
      create!(name: name, taken_at: taken_at, filters: taking.filters, panes: taking.panes)
    end

    def stored_result(pane)
      key = pane.lookup_key
      entry = panes.find { |stored| stored.slice(*key.keys) == key }
      raise NotFound, "snapshot #{id} has no pane #{key.compact.values.join(' ')}" unless entry

      entry["result"]
    end

    class Taking
      attr_reader :filters, :panes

      def initialize(filters)
        @filters = filters
        @panes = []
      end

      def pane(model, measure, by: nil, granularity: nil, limit: nil, on: nil)
        pane = Pane.new(definition: model.janela, measure: measure, dimension: by,
                        granularity: granularity, limit: limit, filters: filters)
        panes << pane.lookup_key.merge("result" => plain(pane.result(on: on)))
      end

      private
        # BigDecimal would otherwise be encoded as a JSON string.
        def plain(result)
          case result
          when Hash then result.transform_values { |v| plain(v) }
          when BigDecimal then result.to_f
          else result
          end
        end
    end
  end
end
