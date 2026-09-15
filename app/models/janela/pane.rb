module Janela
  # One pane of a dashboard: a measure, optionally grouped by a dimension,
  # rendered as a single value, a table or a chart. A pane ignores filters on
  # its own dimension so that clicking a value re-scopes the other panes
  # rather than collapsing this one to the value clicked.
  class Pane
    RENDERERS = %w[table bar].freeze

    attr_reader :definition, :measure, :dimension, :renderer, :filters

    # The helper renders the frame and the controller renders its replacement,
    # so both derive the id the same way from the same parameters.
    def self.frame_id(model:, measure:, by: nil, as: :table)
      [ "janela", model.model_name.route_key, measure, by, (as unless by.nil?) ].compact.join("_")
    end

    def initialize(definition:, measure:, dimension: nil, renderer: "table", filters: {})
      @definition = definition
      @measure = measure
      @dimension = dimension
      @renderer = renderer.to_s
      @filters = filters

      raise Error, "unknown pane renderer #{renderer.inspect}" unless RENDERERS.include?(@renderer)
    end

    def model
      definition.model
    end

    def single_value?
      dimension.nil?
    end

    def chart?
      !single_value? && renderer != "table"
    end

    def frame_id
      self.class.frame_id(model: model, measure: measure, by: dimension, as: renderer)
    end

    def title
      single_value? ? measure.to_s.humanize : "#{measure.to_s.humanize} by #{dimension.to_s.humanize}"
    end

    def result(on: nil)
      definition.query(measure, by: dimension, where: applicable_filters, on: on)
    end

    def filter_key
      "#{ransack_name}_eq" unless single_value?
    end

    # The filter on this pane's own dimension is not applied to its query, but
    # it is what the user clicked here, so the view highlights it.
    def selected_value
      return if single_value?

      filters[filter_key] || filters[filter_key.to_sym]
    end

    private
      def ransack_name
        definition.dimension!(dimension).ransack_name
      end

      def applicable_filters
        return filters if single_value?

        filters.reject { |key, _| key.to_s.start_with?(ransack_name) }
      end
  end
end
