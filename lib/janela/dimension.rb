module Janela
  class Dimension
    GRANULARITIES = %w[hour day week month quarter year].freeze

    LABELS = {
      "hour" => ->(t) { t.strftime("%Y-%m-%d %H:00") },
      "day" => ->(t) { t.strftime("%Y-%m-%d") },
      "week" => ->(t) { t.strftime("%Y-%m-%d") },
      "month" => ->(t) { t.strftime("%b %Y") },
      "quarter" => ->(t) { "Q#{(t.month - 1) / 3 + 1} #{t.year}" },
      "year" => ->(t) { t.strftime("%Y") }
    }.freeze

    attr_reader :name, :model, :through, :granularity

    def initialize(name, model:, through: nil, granularity: nil)
      @name = name
      @model = model
      @through = through
      @granularity = granularity&.to_s

      raise Error, "#{model} has no association #{through.inspect}" if through && reflection.nil?
      self.class.granularity!(@granularity) if @granularity
    end

    def self.granularity!(value)
      value = value.to_s
      raise Error, "unknown granularity #{value.inspect}, use one of #{GRANULARITIES.join(', ')}" unless GRANULARITIES.include?(value)
      value
    end

    def time?
      !granularity.nil?
    end

    def attribute
      klass.arel_table[name]
    end

    def qualified_column
      "#{klass.table_name}.#{name}"
    end

    def ransack_name
      through ? "#{through}_#{name}" : name.to_s
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
