module Janela
  class Dimension
    attr_reader :name, :model, :through

    def initialize(name, model:, through: nil)
      @name = name
      @model = model
      @through = through

      raise Error, "#{model} has no association #{through.inspect}" if through && reflection.nil?
    end

    def attribute
      klass.arel_table[name]
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
