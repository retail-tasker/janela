module Janela
  class Definition
    attr_reader :model, :measures, :dimensions

    def initialize(model)
      @model = model
      @measures = {}
      @dimensions = {}
    end

    def measure(name, **aggregate)
      measures[name] = Measure.build(name, **aggregate)
    end

    def dimension(name, through: nil)
      dimensions[name] = Dimension.new(name, model: model, through: through)
    end

    # Filters are Ransack params, so a host can pass params[:q] straight
    # through from a search_form_for slicer. Scope with on: to respect the
    # host's authorisation, e.g. on: policy_scope(Order).
    def query(measure_name, by: nil, where: {}, on: nil)
      relation = filter(on || model.all, where)

      if by
        dimension = dimension!(by)
        relation = relation.left_joins(dimension.through) if dimension.through
        relation = relation.group(dimension.attribute)
      end

      measure!(measure_name).apply(relation)
    end

    def dimension!(name)
      dimensions.fetch(name) { raise Error, "#{model} has no janela dimension #{name.inspect}" }
    end

    def ransackable_attributes
      dimensions.values.reject(&:through).map { |dimension| dimension.name.to_s }
    end

    def ransackable_associations
      dimensions.values.filter_map(&:through).map(&:to_s).uniq
    end

    private
      def filter(relation, params)
        return relation if params.empty?

        search = relation.ransack(params)
        reject_dropped_filters!(search, params)
        search.result
      end

      # Ransack silently discards conditions an allowlist does not permit,
      # which would quietly return unfiltered numbers.
      def reject_dropped_filters!(search, params)
        applied = search.conditions.flat_map { |condition| condition.attributes.map(&:name) }
        dropped = params.keys.reject { |key| applied.any? { |name| key.to_s.start_with?(name) } }
        return if dropped.empty?

        raise Error, "#{model} does not allow filtering on #{dropped.join(', ')} -- " \
                     "declare a janela dimension, or add it to ransackable_attributes"
      end

      def measure!(name)
        measures.fetch(name) { raise Error, "#{model} has no janela measure #{name.inspect}" }
      end
  end
end
