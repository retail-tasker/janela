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
    # keys: narrows a categorical grouping to the labels a companion column is
    # being fetched for (ADR 051), so it is the primary's rows and not the
    # companion's own top 1000.
    def query(measure_name, by: nil, where: {}, on: nil, granularity: nil, limit: nil, keys: nil)
      measure = measure!(measure_name)
      relation = filter(on || model.all, where)
      return measure.apply(relation) if by.nil?

      dimension = dimension!(by)
      relation = relation.left_joins(dimension.through) if dimension.through

      if dimension.time?
        granularity = Dimension.granularity!(granularity || dimension.granularity)
        bucketed(measure, dimension, relation, granularity).transform_keys { |bucket| dimension.label(bucket, granularity) }
      else
        relation = within_keys(relation, dimension, keys) if keys
        grouped = relation.group(dimension.attribute).order(Arel.sql("#{measure.order_by} DESC"))
        grouped = grouped.limit(limit ? limit!(limit) : MAXIMUM)
        measure.apply(grouped).transform_keys { |value| value.nil? ? Dimension::NONE : value }
      end
    end

    # The buckets of a time dimension keyed by the bucket itself, where query
    # keys them by label. A label is lossy ("Sep 2026", "Q3 2026"), and a click
    # on a bucket has to write the range it covers, which only the bucket can
    # say (ADR 045).
    def series(measure_name, by:, where: {}, on: nil, granularity: nil)
      measure = measure!(measure_name)
      dimension = dimension!(by)
      raise Error, "#{by.inspect} is not a time dimension" unless dimension.time?

      relation = filter(on || model.all, where)
      relation = relation.left_joins(dimension.through) if dimension.through
      bucketed(measure, dimension, relation, Dimension.granularity!(granularity || dimension.granularity))
    end

    # Facts about each label of a dimension, for a table's companion columns
    # (ADR 051): each named dimension's value where every row of the group
    # shares one, and nil where they differ or are all null. Never a guess:
    # grouping by the fact would show a label twice, and MAX would show an
    # arbitrary one as though it were the answer. MIN = MAX is one expression
    # that works on every database, with no extra grouping.
    def facts(names, by:, where: {}, on: nil, keys: nil)
      dimension = dimension!(by)
      raise Error, "#{by.inspect} is a time dimension, and a bucket has no fact its rows share" if dimension.time?

      wanted = names.map { |name| dimension!(name) }
      relation = filter(on || model.all, where)
      ([ dimension ] + wanted).filter_map(&:through).uniq.each { |through| relation = relation.left_joins(through) }
      relation = within_keys(relation, dimension, keys) if keys
      shared = wanted.map do |fact|
        column = fact.quoted_column
        Arel.sql("CASE WHEN MIN(#{column}) = MAX(#{column}) THEN MIN(#{column}) END")
      end

      relation.group(dimension.attribute).pluck(dimension.attribute, *shared).to_h do |key, *values|
        [ key.nil? ? Dimension::NONE : key, names.zip(values).to_h ]
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
                   "Use ratio: #{measure.column.inspect} for the share of rows where it is true, " \
                   "or declare dimension #{measure.column.inspect} and read the split."
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

    # A filter the host fixed for a render (ADR 040), applied as its own
    # condition before the reader's, so the reader's can only narrow inside
    # it. The same bounds as any filter: declared dimensions, ADR 025's
    # predicates and value limit.
    def narrow(relation, conditions)
      filter(relation, conditions.to_h)
    end

    private
      def within_keys(relation, dimension, keys)
        labels = keys - [ Dimension::NONE ]
        condition = dimension.attribute.in(labels)
        condition = condition.or(dimension.attribute.eq(nil)) if keys.include?(Dimension::NONE)
        relation.where(condition)
      end

      def bucketed(measure, dimension, relation, granularity)
        options = granularity == "week" ? { week_start: Date.beginning_of_week } : {}
        measure.apply(relation.group_by_period(granularity, dimension.qualified_column, **options))
      end

      def filter(relation, params)
        return relation if params.empty?

        search = relation.ransack(params)
        reject_dropped_filters!(search, params)
        reject_disallowed_predicates!(search)
        reject_oversized_filters!(search)

        rest, unions = split_selections(params)
        return search.result if unions.empty?

        # Checked as one AND above, so the bounds see every key. Built as the
        # union below (ADR 049).
        unions.reduce(rest.empty? ? relation : relation.ransack(rest).result) do |result, union|
          result.merge(relation.klass.ransack(g: [ union.merge("m" => "or") ]).result)
        end
      end

      # A value and the null group are two ways of being selected, so together
      # they are a union, and Ransack ANDs what it is given: a dimension with
      # both would ask for rows that are both null and web and return nothing
      # (ADR 024 measured it). Ransack's own grouping says OR, used here and
      # never in a URL a person reads. Only inclusions union: two exclusions
      # (not_in, not_null) are two ways of being ruled out and stay an
      # intersection (ADR 049).
      def split_selections(params)
        rest = params.to_h.stringify_keys
        # not_null also ends in _null, and it is an exclusion.
        unions = rest.keys.grep(/(?<!_not)_null\z/).filter_map do |null_key|
          next unless ActiveModel::Type::Boolean.new.cast(rest[null_key]) == true

          base = null_key.delete_suffix("_null")
          members = %W[#{base}_in #{base}_eq].select { |key| Array(rest[key]).any?(&:present?) }
          next if members.empty?

          (members + [ null_key ]).to_h { |key| [ key, rest.delete(key) ] }
        end

        [ rest, unions ]
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
