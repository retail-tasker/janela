module Janela
  # A snapshot freezes the results of several panes at one instant under one
  # set of filters, so an audience sees exactly what was signed off while the
  # live dashboard stays editable (ADR 009). Results are stored, not HTML; the
  # renderer is chosen by whoever shows a stored pane.
  class Snapshot < ActiveRecord::Base
    # Janela sets what it is handed and reads nothing from it. The column
    # exists so a multi tenant host's policy has something to filter a
    # snapshot on, the same as a frame's (ADR 033).
    belongs_to :owner, polymorphic: true, optional: true

    attribute :filters, default: -> { {} }
    attribute :panes, default: -> { [] }

    validates :name, :taken_at, presence: true

    # The owner is an argument rather than something asked of a controller,
    # because a snapshot is never taken in a request: this runs in a job, a
    # task, a console or a host's own code, and the caller is the only thing
    # that knows the answer (ADR 033).
    def self.take(name:, owner: nil, filters: {}, taken_at: Time.current)
      taking = Taking.new(filters.to_h.stringify_keys)
      yield taking
      create!(name: name, owner: owner, taken_at: taken_at, filters: taking.filters, panes: taking.panes)
    end

    def stored_result(query)
      key = query.lookup_key
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
        query = Query.new(definition: model.janela, measure: measure, dimension: by,
                          granularity: granularity, limit: limit, filters: filters)
        panes << query.lookup_key.merge("result" => plain(query.result(on: on)))
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
