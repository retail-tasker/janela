module Janela
  class Measure
    AGGREGATES = %i[sum count average minimum maximum].freeze
    # Aggregates whose answer is a number, so a boolean column would have its
    # result cast back to true or false by ActiveRecord.
    NUMERIC = %i[sum average].freeze
    # Declared beside the aggregate, so they are taken out before the one
    # remaining option is read as the aggregate.
    FORMATS = %i[precision prefix suffix].freeze
    # Where neither the aggregate nor the column says how many decimal places
    # the measure means, two: enough for a rate or a currency, and short of
    # the noise a float carries (issue #25).
    FALLBACK_PRECISION = 2
    # A ratio is a percentage, and a percentage carries two more significant
    # figures than the fraction it came from, so one decimal place is enough
    # and two is noise (ADR 038).
    RATIO_PRECISION = 1

    attr_reader :name, :aggregate, :column, :prefix, :suffix

    def self.build(name, model: nil, **options)
      format = options.extract!(*FORMATS)
      aggregate, column = options.first
      # A ratio sits beside the five aggregates in the same position rather
      # than among them: it names a column and an intent, not an SQL function
      # (ADR 038).
      unless options.size == 1 && (AGGREGATES.include?(aggregate) || aggregate == :ratio)
        raise Error, "measure #{name.inspect} needs exactly one of #{AGGREGATES.join(', ')}, ratio"
      end

      new(name, aggregate, column == true ? nil : column, model: model, **format)
    end

    def initialize(name, aggregate, column, model: nil, precision: nil, prefix: nil, suffix: nil)
      @name = name
      @aggregate = aggregate
      @column = column
      @model = model
      @precision = precision!(precision)
      @prefix = prefix
      @suffix = suffix
      check_ratio! if ratio?
    end

    def ratio?
      aggregate == :ratio
    end

    def apply(relation)
      return relation.average(ratio_expression) if ratio?

      column ? relation.public_send(aggregate, column) : relation.public_send(aggregate)
    end

    # What a grouped relation is ordered by to put the measure's largest
    # first. An aggregate has the column alias ActiveRecord gives a grouped
    # calculation, and a ratio has no alias to name, so it orders by the
    # expression itself (ADR 007, ADR 038).
    def order_by
      ratio? ? "AVG(#{ratio_expression})" : "#{aggregate}_#{column || 'all'}"
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
      return "" if value.nil?
      return value.to_s unless value.is_a?(Numeric)
      # The number stays the fraction everywhere it is stored, ordered and
      # compared; only this string is a percentage (ADR 038).
      return "#{rounded(value * 100)}%" if ratio?

      "#{prefix}#{rounded(value)}#{suffix}"
    end

    private
      # An unknown is not a failure: the null arm leaves it out of the average,
      # which is exactly what AVG does with a null and what the naive CASE does
      # not. The column is looked up in the model's schema at declaration and
      # quoted here, never taken from anything that arrived over HTTP.
      def ratio_expression
        @ratio_expression ||= begin
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

        type = @model.type_for_attribute(column.to_s).type
        return if type == :boolean

        raise Error, "measure #{name.inspect} takes a ratio of #{@model}##{column}, which is " \
                     "#{type ? "a #{type} column" : 'not a column'}, not a boolean. A ratio is the share of rows where " \
                     "a yes or no fact is yes; for anything else declare a dimension and read the split."
      rescue ActiveRecord::ActiveRecordError
        nil # no database to ask yet; a query will raise on its own if it cannot run
      end

      def rounded(value)
        ActiveSupport::NumberHelper.number_to_rounded(value, precision: precision,
          delimiter: I18n.t("number.format.delimiter", default: ","))
      end

      # Asking the schema rather than the value: one bucket of a measure can
      # land on a whole number without the measure being a whole number.
      def column_scale
        return 0 if aggregate == :count || column.nil?

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
