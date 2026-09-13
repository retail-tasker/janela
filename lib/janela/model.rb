module Janela
  module Model
    def janela(&block)
      return @janela_definition unless block

      @janela_definition = Definition.new(self)
      @janela_definition.instance_eval(&block)
      define_janela_ransack_allowlist
      Janela.register(self)
      @janela_definition
    end

    private
      # Dimensions are the only things Janela filters on, so they are the
      # Ransack allowlist. A model that already declares its own allowlist
      # keeps it.
      def define_janela_ransack_allowlist
        return if singleton_class.method_defined?(:ransackable_attributes, false)

        definition = @janela_definition
        define_singleton_method(:ransackable_attributes) { |_auth_object = nil| definition.ransackable_attributes }
        define_singleton_method(:ransackable_associations) { |_auth_object = nil| definition.ransackable_associations }
      end
  end
end
