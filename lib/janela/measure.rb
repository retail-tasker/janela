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

    attr_reader :name, :aggregate, :column, :prefix, :suffix

    def self.build(name, model: nil, **options)
      format = options.extract!(*FORMATS)
      aggregate, column = options.first
      unless options.size == 1 && AGGREGATES.include?(aggregate)
        raise Error, "measure #{name.inspect} needs exactly one of #{AGGREGATES.join(', ')}"
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
    end

    def apply(relation)
      column ? relation.public_send(aggregate, column) : relation.public_send(aggregate)
    end

    # The column alias ActiveRecord gives a grouped calculation, so a
    # relation can be ordered by the measure before it is calculated.
    def sql_alias
      "#{aggregate}_#{column || 'all'}"
    end

    # How many decimal places this measure means. Counting rows has none, and
    # a decimal column already declares its own scale, so money and counts
    # read correctly with nothing declared at all (ADR 020).
    def precision
      @precision || column_scale || FALLBACK_PRECISION
    end

    # Rendering, never rounding: the number itself reaches a snapshot and a
    # comparison at full precision, so a stored pane reads back under whatever
    # format is declared later (ADR 009). Anything that is not a number is
    # left alone, since minimum of a string is still that string.
    def format(value)
      return "" if value.nil?
      return value.to_s unless value.is_a?(Numeric)

      "#{prefix}#{rounded(value)}#{suffix}"
    end

    private
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
