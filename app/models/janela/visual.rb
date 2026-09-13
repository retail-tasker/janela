module Janela
  # One measure grouped by one dimension. A visual ignores filters on its own
  # dimension: clicking a value in a visual should re-scope the others, not
  # collapse itself to the single value that was clicked.
  class Visual
    attr_reader :definition, :measure, :dimension, :filters

    # The helper renders the frame and the controller renders its replacement,
    # so both derive the id the same way from the same three parameters.
    def self.frame_id(model:, measure:, by:)
      "janela_#{model.to_s.underscore}_#{measure}_by_#{by}"
    end

    def initialize(definition:, measure:, dimension:, filters: {})
      @definition = definition
      @measure = measure
      @dimension = dimension
      @filters = filters
    end

    def model
      definition.model
    end

    def frame_id
      self.class.frame_id(model: model.name, measure: measure, by: dimension)
    end

    def result(on: nil)
      definition.query(measure, by: dimension, where: applicable_filters, on: on)
    end

    def filter_key
      "#{ransack_name}_eq"
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
