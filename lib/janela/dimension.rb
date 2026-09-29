module Janela
  class Dimension
    GRANULARITIES = %w[hour day week month quarter year].freeze

    # What a click produces (ADR 024), plus not_null: excluding the null
    # group is documented, tested behaviour ADR 025 did not measure and would
    # otherwise silently break. not_eq and not_in (ADR 044) say what a
    # dimension excludes, which an _in list naming every other value cannot
    # do without rotting the day a new value appears.
    CATEGORICAL_PREDICATES = %w[eq in not_eq not_in null not_null].freeze

    # A time dimension additionally narrows a range (ADR 006).
    TIME_PREDICATES = (CATEGORICAL_PREDICATES + %w[gteq gt lteq lt]).freeze

    # How far a bucket reaches, so a click on it can name the range it covers
    # (ADR 045). A quarter is three months, which is why it is not a step of
    # its own.
    STEPS = { "hour" => 1.hour, "day" => 1.day, "week" => 1.week, "month" => 1.month,
              "quarter" => 3.months, "year" => 1.year }.freeze

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

    # The bucket's start and the next bucket's start, in the zone the bucket
    # was made in. The end is exclusive, so one bucket's end is the next
    # one's start and no row falls in both (ADR 045).
    def span(bucket, granularity = self.granularity)
      from = bucket.in_time_zone
      [ from, from + STEPS.fetch(granularity.to_s) ]
    end

    # The same range as the two values a filter carries: dates for a date
    # column, and for a timestamp the zone's ISO 8601 with its offset, which
    # Ransack reads back in the same zone (measured against Brisbane).
    def bounds(bucket, granularity = self.granularity)
      span(bucket, granularity).map { |moment| date_column? ? moment.to_date.iso8601 : moment.iso8601 }
    end

    def date_column?
      klass.type_for_attribute(column.to_s).type == :date
    rescue ActiveRecord::ActiveRecordError
      false
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
