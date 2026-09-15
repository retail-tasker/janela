module Janela
  # The query behind one pane: a measure, optionally grouped by a dimension,
  # rendered as a single value, a table or a chart. A query ignores filters on
  # its own dimension so that clicking a value re-scopes the other panes
  # rather than collapsing this one to the value clicked. A query read from a
  # snapshot shows stored results and cannot be clicked at all.
  class Query
    RENDERERS = %w[table bar line].freeze

    attr_reader :definition, :measure, :dimension, :renderer, :limit, :filters, :snapshot

    # The helper renders the turbo frame and the controller renders its
    # replacement, so both derive the id the same way from the same parameters.
    def self.turbo_frame_id(model:, measure:, by: nil, as: :table, granularity: nil, limit: nil, snapshot: nil)
      parts = [ "janela", ("snapshot_#{snapshot.id}" if snapshot), model.model_name.route_key, measure, by,
                (granularity if by), (as unless by.nil?), ("top#{limit}" if by && limit) ]
      parts.compact.join("_")
    end

    def initialize(definition:, measure:, dimension: nil, renderer: "table", granularity: nil, limit: nil, filters: {}, snapshot: nil)
      @definition = definition
      @measure = measure
      @dimension = dimension
      @renderer = renderer.to_s
      @filters = filters
      @snapshot = snapshot

      raise BadRequest, "unknown pane renderer #{renderer.inspect}" unless RENDERERS.include?(@renderer)
      @granularity = Dimension.granularity!(granularity) if granularity.present?
      @limit = definition.limit!(limit) if limit.present?
    end

    def model
      definition.model
    end

    def single_value?
      dimension.nil?
    end

    def time?
      !single_value? && dimension_definition.time?
    end

    def frozen?
      !snapshot.nil?
    end

    def granularity
      @granularity || (dimension_definition.granularity if time?)
    end

    # Clicking a category adds one Ransack condition; clicking a time bucket
    # would need two, and the dashboard toggles one key at a time (ADR 006).
    # A stored pane is the record of a moment and is not clickable (ADR 009).
    def clickable?
      !single_value? && !time? && !frozen?
    end

    def chart?
      !single_value? && renderer != "table"
    end

    def turbo_frame_id
      self.class.turbo_frame_id(model: model, measure: measure, by: dimension, as: renderer,
                          granularity: @granularity, limit: limit, snapshot: snapshot)
    end

    def title
      base = if single_value?
        measure.to_s.humanize
      else
        by = "#{measure.to_s.humanize} by #{dimension.to_s.humanize}"
        time? ? "#{by} per #{granularity}" : by
      end
      frozen? ? "#{base} as of #{snapshot.taken_at.strftime('%-d %b %Y')}" : base
    end

    # What identifies this pane's data inside a snapshot.
    def lookup_key
      { "model" => model.model_name.route_key, "measure" => measure.to_s, "dimension" => dimension&.to_s,
        "granularity" => granularity&.to_s, "limit" => limit }
    end

    def result(on: nil)
      return snapshot.stored_result(self) if frozen?

      definition.query(measure, by: dimension, where: applicable_filters, on: on, granularity: granularity, limit: limit)
    end

    # The Ransack key and value a click on this label should toggle. A null
    # group filters with the null predicate, not an empty string (ADR 009 has
    # no say here; see issue #21).
    def filter_params(label)
      return [ nil, nil ] unless clickable?
      return [ "#{ransack_name}_null", "1" ] if label.to_s == Dimension::NONE

      [ "#{ransack_name}_eq", label.to_s ]
    end

    # Every label in this pane paired with the filter it toggles, for a chart
    # to look up by label when a bar is clicked.
    def filters_for(labels)
      return {} unless clickable?

      labels.to_h { |label| [ label.to_s, filter_params(label) ] }
    end

    # The filter on this pane's own dimension is not applied to its query, but
    # it is what the user clicked here, so the view highlights it.
    def selected_value
      return unless clickable?
      return Dimension::NONE if filter("#{ransack_name}_null").present?

      filter("#{ransack_name}_eq")
    end

    private
      def filter(key)
        filters[key] || filters[key.to_sym]
      end

      def dimension_definition
        definition.dimension!(dimension)
      end

      def ransack_name
        dimension_definition.ransack_name
      end

      def applicable_filters
        return filters if single_value? || time?

        filters.reject { |key, _| key.to_s.start_with?(ransack_name) }
      end
  end
end
