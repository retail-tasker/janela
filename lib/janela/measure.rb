module Janela
  class Measure
    AGGREGATES = %i[sum count average minimum maximum].freeze
    # Aggregates whose answer is a number, so a boolean column would have its
    # result cast back to true or false by ActiveRecord.
    NUMERIC = %i[sum average].freeze

    attr_reader :name, :aggregate, :column

    def self.build(name, **options)
      aggregate, column = options.first
      unless options.size == 1 && AGGREGATES.include?(aggregate)
        raise Error, "measure #{name.inspect} needs exactly one of #{AGGREGATES.join(', ')}"
      end

      new(name, aggregate, column == true ? nil : column)
    end

    def initialize(name, aggregate, column)
      @name = name
      @aggregate = aggregate
      @column = column
    end

    def apply(relation)
      column ? relation.public_send(aggregate, column) : relation.public_send(aggregate)
    end

    # The column alias ActiveRecord gives a grouped calculation, so a
    # relation can be ordered by the measure before it is calculated.
    def sql_alias
      "#{aggregate}_#{column || 'all'}"
    end
  end
end
