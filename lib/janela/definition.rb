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

    def dimension(name, through: nil, granularity: nil)
      dimensions[name] = Dimension.new(name, model: model, through: through, granularity: granularity)
    end

    # Filters are Ransack params, so a host can pass params[:q] straight
    # through from a search_form_for slicer. Scope with on: to respect the
    # host's authorisation, e.g. on: policy_scope(Order). A time dimension
    # buckets by its declared granularity unless one is given.
    def query(measure_name, by: nil, where: {}, on: nil, granularity: nil)
      relation = filter(on || model.all, where)
      return measure!(measure_name).apply(relation) if by.nil?

      dimension = dimension!(by)
      relation = relation.left_joins(dimension.through) if dimension.through

      if dimension.time?
        granularity = Dimension.granularity!(granularity || dimension.granularity)
        options = granularity == "week" ? { week_start: Date.beginning_of_week } : {}
        buckets = relation.group_by_period(granularity, dimension.qualified_column, **options)
        measure!(measure_name).apply(buckets).transform_keys { |bucket| dimension.label(bucket, granularity) }
      else
        measure!(measure_name).apply(relation.group(dimension.attribute))
      end
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

        raise Error, "#{model} does not allow filtering on #{dropped.join(', ')}. " \
                     "Declare a janela dimension, or add it to ransackable_attributes."
      end

      def measure!(name)
        measures.fetch(name) { raise Error, "#{model} has no janela measure #{name.inspect}" }
      end
  end
end
