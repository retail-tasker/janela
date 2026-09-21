module Janela
  class Definition
    # ADR 007's existing ceiling on a limit, reused by ADR 025 as the default
    # applied when a host asks for none, and as the bound on one filter's values.
    MAXIMUM = 1000

    attr_reader :model, :measures, :dimensions

    # The class whose janela block this is, which a subclass shares with the
    # parent it inherited from. A subclass gets a definition of its own, so
    # anything reporting on a declaration rather than on a model groups by
    # this or says the same thing once per class in an STI family (ADR 035).
    attr_accessor :declared_by

    def initialize(model, &block)
      @model = model
      @declared_by = model
      @measures = {}
      @dimensions = {}
      @block = block
      instance_eval(&block) if block
    end

    # The same declaration read against another model, which is how a subclass
    # inherits a dashboard: its measures and dimensions are its parent's, and
    # the queries they run are its own, because ActiveRecord adds the type
    # condition to a relation on the subclass (ADR 031).
    def for(model)
      self.class.new(model, &@block).tap { |inherited| inherited.declared_by = declared_by }
    end

    def measure(name, **aggregate)
      measures[name] = Measure.build(name, model: model, **aggregate).tap { |measure| reject_boolean_column!(measure) }
    end

    def dimension(name, through: nil, column: nil, granularity: nil)
      dimensions[name] = Dimension.new(name, model: model, through: through, column: column, granularity: granularity)
    end

    # Filters are Ransack params, so a host can pass params[:q] straight
    # through from a search_form_for slicer. Scope with on: to respect the
    # host's authorisation, e.g. on: policy_scope(Order). A time dimension
    # buckets by its declared granularity unless one is given.
    def query(measure_name, by: nil, where: {}, on: nil, granularity: nil, limit: nil)
      measure = measure!(measure_name)
      relation = filter(on || model.all, where)
      return measure.apply(relation) if by.nil?

      dimension = dimension!(by)
      relation = relation.left_joins(dimension.through) if dimension.through

      if dimension.time?
        granularity = Dimension.granularity!(granularity || dimension.granularity)
        options = granularity == "week" ? { week_start: Date.beginning_of_week } : {}
        buckets = relation.group_by_period(granularity, dimension.qualified_column, **options)
        measure.apply(buckets).transform_keys { |bucket| dimension.label(bucket, granularity) }
      else
        grouped = relation.group(dimension.attribute).order(Arel.sql("#{measure.sql_alias} DESC"))
        grouped = grouped.limit(limit ? limit!(limit) : MAXIMUM)
        measure.apply(grouped).transform_keys { |value| value.nil? ? Dimension::NONE : value }
      end
    end

    def dimension!(name)
      dimensions.fetch(name) { raise NotFound, "#{model} has no janela dimension #{name.inspect}" }
    end

    def measure!(name)
      measures.fetch(name) { raise NotFound, "#{model} has no janela measure #{name.inspect}" }
    end

    # ActiveRecord casts an aggregate back through the column's own type, so
    # AVG over a boolean returns true rather than a ratio. Say so at
    # declaration rather than rendering a meaningless pane.
    def reject_boolean_column!(measure)
      return unless measure.column && Measure::NUMERIC.include?(measure.aggregate)
      return unless model.type_for_attribute(measure.column).type == :boolean

      raise Error, "measure #{measure.name.inspect} takes #{measure.aggregate} of the boolean " \
                   "#{model}##{measure.column}, which ActiveRecord casts back to true or false. " \
                   "Declare dimension #{measure.column.inspect} instead and read the split."
    rescue ActiveRecord::ActiveRecordError
      nil # no database to ask yet; a query will raise on its own if it cannot run
    end

    def limit!(value)
      limit = Integer(value, exception: false)
      raise BadRequest, "limit must be a whole number from 1 to #{MAXIMUM}, got #{value.inspect}" unless limit&.between?(1, MAXIMUM)
      limit
    end

    def ransackable_attributes
      dimensions.values.reject(&:through).map { |dimension| dimension.column.to_s }
    end

    def ransackable_associations
      dimensions.values.filter_map(&:through).map(&:to_s).uniq
    end

    private
      def filter(relation, params)
        return relation if params.empty?

        search = relation.ransack(params)
        reject_dropped_filters!(search, params)
        reject_disallowed_predicates!(search)
        reject_oversized_filters!(search)
        search.result
      end

      # Ransack silently discards conditions an allowlist does not permit,
      # which would quietly return unfiltered numbers.
      def reject_dropped_filters!(search, params)
        applied = search.conditions.flat_map { |condition| condition.attributes.map(&:name) }
        dropped = params.keys.reject { |key| applied.any? { |name| key.to_s.start_with?(name) } }
        return if dropped.empty?

        raise BadRequest, "#{model} does not allow filtering on #{dropped.join(', ')}. " \
                     "Declare a janela dimension, or add it to ransackable_attributes."
      end

      # An allowed attribute still reaches every predicate Ransack knows,
      # including _matches, an arbitrary LIKE pattern (ADR 025). A dashboard
      # asks in only the predicates its kind of dimension needs.
      def reject_disallowed_predicates!(search)
        by_ransack_name = dimensions.values.index_by(&:ransack_name)

        search.conditions.each do |condition|
          condition.attributes.each do |attribute|
            dimension = by_ransack_name.fetch(attribute.name)
            next if dimension.allowed_predicates.include?(condition.predicate_name)

            allowed = dimension.allowed_predicates.map { |predicate| "#{attribute.name}_#{predicate}" }
            raise BadRequest, "#{model} does not allow #{attribute.name}_#{condition.predicate_name}. " \
                         "This dimension allows #{allowed.join(', ')}."
          end
        end
      end

      # A click writes _in (ADR 024), which takes an array Ransack does not
      # otherwise bound. 5001 values answered rather than being refused.
      def reject_oversized_filters!(search)
        search.conditions.each do |condition|
          next unless condition.predicate.wants_array
          next if condition.values.size <= MAXIMUM

          raise BadRequest, "#{model} does not allow a filter to carry more than #{MAXIMUM} values, " \
                       "got #{condition.values.size} for #{condition.attributes.map(&:name).join(', ')}."
        end
      end
  end
end
