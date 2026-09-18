module Janela
  class Dimension
    GRANULARITIES = %w[hour day week month quarter year].freeze

    # What a click produces (ADR 024), plus not_null: excluding the null
    # group is documented, tested behaviour ADR 025 did not measure and would
    # otherwise silently break.
    CATEGORICAL_PREDICATES = %w[eq in null not_null].freeze

    # A time dimension additionally narrows a range (ADR 006).
    TIME_PREDICATES = (CATEGORICAL_PREDICATES + %w[gteq gt lteq lt]).freeze

    # A group of rows whose dimension is null. Labelled rather than blank, and
    # filtered with Ransack's null predicate rather than an empty string.
    NONE = "(none)".freeze

    LABELS = {
      "hour" => ->(t) { t.strftime("%Y-%m-%d %H:00") },
      "day" => ->(t) { t.strftime("%Y-%m-%d") },
      "week" => ->(t) { t.strftime("%Y-%m-%d") },
      "month" => ->(t) { t.strftime("%b %Y") },
      "quarter" => ->(t) { "Q#{(t.month - 1) / 3 + 1} #{t.year}" },
      "year" => ->(t) { t.strftime("%Y") }
    }.freeze

    attr_reader :name, :model, :through, :column, :granularity

    # A dimension is named for what it means on the dashboard and reads a
    # column that may be called something else, usually on an association:
    # dimension :customer, through: :customer, column: :name.
    def initialize(name, model:, through: nil, column: nil, granularity: nil)
      @name = name
      @model = model
      @through = through
      @column = (column || name).to_sym
      @granularity = granularity&.to_s

      raise Error, "#{model} has no association #{through.inspect}" if through && reflection.nil?
      self.class.granularity!(@granularity) if @granularity
    end

    def self.granularity!(value)
      value = value.to_s
      raise BadRequest, "unknown granularity #{value.inspect}, use one of #{GRANULARITIES.join(', ')}" unless GRANULARITIES.include?(value)
      value
    end

    def time?
      !granularity.nil?
    end

    # Which Ransack predicates a filter on this dimension may use (ADR 025).
    def allowed_predicates
      time? ? TIME_PREDICATES : CATEGORICAL_PREDICATES
    end

    def attribute
      klass.arel_table[column]
    end

    def qualified_column
      "#{klass.table_name}.#{column}"
    end

    def ransack_name
      through ? "#{through}_#{column}" : column.to_s
    end

    def label(bucket, granularity = self.granularity)
      LABELS.fetch(granularity).call(bucket)
    end

    private
      def klass
        through ? reflection.klass : model
      end

      def reflection
        model.reflect_on_association(through)
      end
  end
end
