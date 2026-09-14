module Janela
  # One measure grouped by one dimension, rendered as a table or a chart. A
  # visual ignores filters on its own dimension: clicking a value in a visual
  # should re-scope the others, not collapse itself to the value clicked.
  class Visual
    RENDERERS = %w[table bar].freeze

    attr_reader :definition, :measure, :dimension, :renderer, :filters

    # The helper renders the frame and the controller renders its replacement,
    # so both derive the id the same way from the same parameters.
    def self.frame_id(model:, measure:, by:, as: :table)
      "janela_#{model.to_s.underscore}_#{measure}_by_#{by}_#{as}"
    end

    def initialize(definition:, measure:, dimension:, renderer: "table", filters: {})
      @definition = definition
      @measure = measure
      @dimension = dimension
      @renderer = renderer.to_s
      @filters = filters

      raise Error, "unknown visual renderer #{renderer.inspect}" unless RENDERERS.include?(@renderer)
    end

    def model
      definition.model
    end

    def chart?
      renderer != "table"
    end

    def frame_id
      self.class.frame_id(model: model.name, measure: measure, by: dimension, as: renderer)
    end

    def title
      "#{measure.to_s.humanize} by #{dimension.to_s.humanize}"
    end

    def result(on: nil)
      definition.query(measure, by: dimension, where: applicable_filters, on: on)
    end

    def filter_key
      "#{ransack_name}_eq"
    end

    # The filter on this visual's own dimension is not applied to its query,
    # but it is what the user clicked here, so the view highlights it.
    def selected_value
      filters[filter_key] || filters[filter_key.to_sym]
    end

    private
      def ransack_name
        definition.dimension!(dimension).ransack_name
      end

      def applicable_filters
        filters.reject { |key, _| key.to_s.start_with?(ransack_name) }
      end
  end
end
