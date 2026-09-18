module Janela
  module Model
    # Dimensions are the only things Janela filters on, so they are the
    # Ransack allowlist. This asks for the definition when it is called rather
    # than closing over one, so a subclass answers with the definition it
    # reports, whether that is its parent's or one it declared itself. The two
    # halves cannot then disagree, which is what they did before ADR 031: a
    # subclass inherited this list and reported no definition behind it.
    module RansackAllowlist
      def ransackable_attributes(_auth_object = nil)
        janela.ransackable_attributes
      end

      def ransackable_associations(_auth_object = nil)
        janela.ransackable_associations
      end
    end

    def janela(&block)
      return @janela_definition ||= inherited_janela_definition unless block

      @janela_definition = Definition.new(self, &block)
      define_janela_ransack_allowlist
      Janela.register(self)
      @janela_definition
    end

    # A subclass cannot be registered where its parent declares, because it
    # does not exist yet, so it registers as it is created (ADR 031). An
    # anonymous class has no route key to be addressed by; naming it is the
    # host's move and declaring on it is the host's other one.
    def inherited(subclass)
      super
      Janela.register_subclass(subclass) if subclass.name && janela
    end

    private
      # What a subclass inherits is the declaration, not the definition
      # object. A definition holds the model it queries, so a subclass handed
      # its parent's would report the right dashboard and then total the
      # parent's rows behind it.
      def inherited_janela_definition
        superclass.janela&.for(self) if superclass.respond_to?(:janela)
      end

      # A model that already answers for itself keeps its answer, whether it
      # said so here or on a class above. Ransack's own default lives on
      # ActiveRecord::Base, so anything nearer than that was somebody's
      # decision and is not ours to replace.
      def define_janela_ransack_allowlist
        return if janela_ransack_allowlist_answered?

        extend RansackAllowlist
      end

      def janela_ransack_allowlist_answered?
        owner = singleton_class.instance_method(:ransackable_attributes).owner
        !ActiveRecord::Base.singleton_class.ancestors.include?(owner)
      end
  end
end
