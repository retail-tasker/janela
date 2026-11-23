module Janela
  class Measure
    AGGREGATES = %i[sum count count_distinct average minimum maximum].freeze
    # Aggregates whose answer is a number, so a boolean column would have its
    # result cast back to true or false by ActiveRecord.
    NUMERIC = %i[sum average].freeze
    # Declared beside the aggregate, so they are taken out before the one
    # remaining option is read as the aggregate.
    FORMATS = %i[precision prefix suffix].freeze
    # A count, a sum and a count of distinct values are true however few rows
    # they are over. Only a measure worked out from its rows can be noise on
    # too few of them (ADR 064).
    SAMPLED = %i[average minimum maximum ratio].freeze
    # What a measure reads as when it has no value: an empty bucket and one
    # under its minimum are the same thing to a reader (ADR 064).
    NO_VALUE = "–".freeze
    # Where neither the aggregate nor the column says how many decimal places
    # the measure means, two: enough for a rate or a currency, and short of
    # the noise a float carries (issue #25).
    FALLBACK_PRECISION = 2
    # A ratio is a percentage, and a percentage carries two more significant
    # figures than the fraction it came from, so one decimal place is enough
    # and two is noise (ADR 038).
    RATIO_PRECISION = 1

    attr_reader :name, :aggregate, :column, :over, :min_rows, :prefix, :suffix

    def self.build(name, model: nil, **options)
      format = options.extract!(*FORMATS)
      over = options.delete(:over)
      min_rows = options.delete(:min_rows)
      aggregate, column = options.first
      # A ratio sits beside the five aggregates in the same position rather
      # than among them: it names a column and an intent, not an SQL function
      # (ADR 038).
      unless options.size == 1 && (AGGREGATES.include?(aggregate) || aggregate == :ratio)
        raise Error, "measure #{name.inspect} needs exactly one of #{AGGREGATES.join(', ')}, ratio"
      end

      new(name, aggregate, column == true ? nil : column, model: model, over: over, min_rows: min_rows, **format)
    end

    def initialize(name, aggregate, column, model: nil, over: nil, min_rows: nil, precision: nil, prefix: nil, suffix: nil)
      @name = name
      @aggregate = aggregate
      @column = column
      @over = over
      @model = model
      @precision = precision!(precision)
      @prefix = prefix
      @suffix = suffix
      raise Error, "measure #{name.inspect} takes over: only as a ratio, e.g. ratio: :visits, over: :target" if over && !ratio?
      check_ratio! if ratio?
      @min_rows = min_rows!(min_rows)
    end

    def ratio?
      aggregate == :ratio
    end

    # One sum over another, rather than the share of rows where a boolean is
    # true (ADR 064).
    def ratio_of_sums?
      ratio? && !over.nil?
    end

    # How a reader names it in a refusal.
    def kind
      { count_distinct: "a count of distinct values", average: "an average" }.fetch(aggregate) { "a #{aggregate}" }
    end

    # A count or a sum adds up across buckets: a running total of it means
    # something, and a bucket with no rows is zero. An average, a minimum, a
    # maximum or a ratio does not, and a bucket with no rows has no value
    # (ADR 062).
    def additive?
      %i[count sum].include?(aggregate)
    end

    def apply(relation)
      return divided(relation.sum(quoted(column)), relation.sum(quoted(over))) if ratio_of_sums?
      return relation.average(boolean_share) if ratio?
      return relation.distinct.count(column) if aggregate == :count_distinct

      column ? relation.public_send(aggregate, column) : relation.public_send(aggregate)
    end

    # What a grouped relation is ordered by, in a direction. An aggregate has
    # the column alias ActiveRecord gives a grouped calculation, and a ratio
    # has no alias to name, so it orders by the expression itself (ADR 007,
    # ADR 038). A ratio of sums with no denominator has no value, and sorts
    # after every group that has one whichever way the pane sorts (ADR 064).
    def order_by(direction = "DESC")
      return "#{expression} #{direction}" if ratio? && !ratio_of_sums?
      return "#{aggregate == :count_distinct ? 'count' : aggregate}_#{column || 'all'} #{direction}" unless ratio_of_sums?

      "#{expression} IS NULL, #{expression} #{direction}"
    end

    # How many decimal places this measure means. Counting rows has none, and
    # a decimal column already declares its own scale, so money and counts
    # read correctly with nothing declared at all (ADR 020).
    def precision
      @precision || (RATIO_PRECISION if ratio?) || column_scale || FALLBACK_PRECISION
    end

    # Rendering, never rounding: the number itself reaches a snapshot and a
    # comparison at full precision, so a stored pane reads back under whatever
    # format is declared later (ADR 009). Anything that is not a number is
    # left alone, since minimum of a string is still that string.
    def format(value)
      return NO_VALUE if value.nil?
      return value.to_s unless value.is_a?(Numeric)
      # The number stays the fraction everywhere it is stored, ordered and
      # compared; only this string is a percentage (ADR 038).
      return "#{rounded(value * 100)}%" if ratio?

      "#{prefix}#{rounded(value)}#{suffix}"
    end

    # The measure as SQL, for ordering inside an expression where the alias
    # cannot be named. Only a measure that can take a minimum needs it.
    def expression
      return "SUM(#{quoted(column)}) * 1.0 / NULLIF(SUM(#{quoted(over)}), 0)" if ratio_of_sums?
      return "AVG(#{boolean_share})" if ratio?

      "#{{ average: 'AVG', minimum: 'MIN', maximum: 'MAX' }.fetch(aggregate)}(#{quoted(column)})"
    end

    private
      # Two sums keyed the same way, by a group or a bucket, or two numbers.
      # Groupdate fills an empty bucket with zero in both, and no denominator
      # is no value rather than an error or infinity.
      def divided(numerators, denominators)
        return quotient(numerators, denominators) unless numerators.is_a?(Hash)

        numerators.to_h { |key, numerator| [ key, quotient(numerator, denominators[key]) ] }
      end

      def quotient(numerator, denominator)
        numerator.to_f / denominator.to_f unless denominator.nil? || denominator.zero?
      end

      def quoted(name)
        Arel.sql("#{@model.quoted_table_name}.#{@model.connection.quote_column_name(name)}")
      end

      # An unknown is not a failure: the null arm leaves it out of the average,
      # which is exactly what AVG does with a null and what the naive CASE does
      # not. The column is looked up in the model's schema at declaration and
      # quoted here, never taken from anything that arrived over HTTP.
      def boolean_share
        @boolean_share ||= begin
          field = "#{@model.quoted_table_name}.#{@model.connection.quote_column_name(column)}"
          Arel.sql("CASE WHEN #{field} IS NULL THEN NULL WHEN #{field} THEN 1.0 ELSE 0.0 END")
        end
      end

      def check_ratio!
        raise Error, "measure #{name.inspect} takes a ratio of a boolean column, e.g. ratio: :passed" unless column

        if prefix || suffix
          raise Error, "measure #{name.inspect} is a ratio, which is always shown as a percentage, so it takes " \
                       "no #{prefix ? 'prefix' : 'suffix'}. Declare a precision if one decimal place is not right."
        end
        return if @model.nil?
        return check_sums! if ratio_of_sums?

        type = @model.type_for_attribute(column.to_s).type
        return if type == :boolean

        raise Error, "measure #{name.inspect} takes a ratio of #{@model}##{column}, which is " \
                     "#{type ? "a #{type} column" : 'not a column'}, not a boolean. A ratio is the share of rows where " \
                     "a yes or no fact is yes; for anything else declare a dimension and read the split."
      rescue ActiveRecord::ActiveRecordError
        nil # no database to ask yet; a query will raise on its own if it cannot run
      end

      # Both sides of a ratio of sums are summed, so both must be numbers. A
      # boolean would be cast back to true or false by ActiveRecord, the same
      # reason a sum of one is refused.
      def check_sums!
        [ column, over ].each do |side|
          type = @model.type_for_attribute(side.to_s).type
          next if %i[integer decimal float].include?(type)

          raise Error, "measure #{name.inspect} takes a ratio of #{column.inspect} over #{over.inspect}, and " \
                       "#{@model}##{side} is #{type ? "a #{type} column" : 'not a column'}. A ratio over another " \
                       "column divides two sums, so both must be numeric; ratio: alone is the share of a boolean."
        end
      end

      def min_rows!(value)
        return if value.nil?

        unless SAMPLED.include?(aggregate)
          raise Error, "measure #{name.inspect} is #{kind}, which is true however few rows it is over, so it takes " \
                       "no min_rows. A minimum is for an average, a minimum, a maximum or a ratio."
        end
        rows = Integer(value, exception: false)
        raise Error, "measure #{name.inspect} takes a min_rows of a whole number above zero, not #{value.inspect}" unless rows&.positive?

        rows
      end

      def rounded(value)
        ActiveSupport::NumberHelper.number_to_rounded(value, precision: precision,
          delimiter: I18n.t("number.format.delimiter", default: ","))
      end

      # Asking the schema rather than the value: one bucket of a measure can
      # land on a whole number without the measure being a whole number.
      def column_scale
        return 0 if %i[count count_distinct].include?(aggregate) || column.nil?

        type = @model&.type_for_attribute(column)
        return if type.nil?
        return 0 if type.type == :integer && aggregate != :average

        type.scale if type.respond_to?(:scale)
      rescue ActiveRecord::ActiveRecordError
        nil # no database to ask yet
      end

      def precision!(value)
        return if value.nil?

        places = Integer(value, exception: false)
        unless places&.between?(0, 10)
          raise Error, "measure #{name.inspect} takes a precision of 0 to 10 decimal places, not #{value.inspect}"
        end

        places
      end
  end
end
