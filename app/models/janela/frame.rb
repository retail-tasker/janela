module Janela
  # A dashboard, as data: a name, a grid, and the panes it holds (ADR 012).
  # A frame is created at runtime by a host, a script or an agent, so nothing
  # about a dashboard has to be deployed.
  class Frame < ActiveRecord::Base
    COLUMNS = (1..12).freeze
    GAPS = (0..8).freeze

    # Janela sets nothing here and reads nothing from it. The column exists so
    # a multi tenant host's Pundit Scope has something to filter on (ADR 014).
    belongs_to :owner, polymorphic: true, optional: true

    has_many :panes, -> { order(:position) }, dependent: :destroy, inverse_of: :frame

    validates :name, presence: true
    validates :columns, inclusion: { in: COLUMNS }
    validates :gap, inclusion: { in: GAPS }
    # The shape of the symbol a host passes, so nothing that reads like a
    # name or a path gets in (ADR 041).
    validates :key, format: { with: /\A[a-z0-9_]+\z/ }, uniqueness: { scope: %i[owner_type owner_id] }, allow_nil: true
    # Present or absent together, and default_where is only ever as valid as
    # default_model says it can be (ADR 043).
    validate :default_where_matches_default_model

    # The host's frame for this owner and key, created on first use (ADR 041).
    # The block runs only when the frame is created, to set what a new frame
    # starts as. Two requests creating it at once end with one row: the unique
    # index refuses the second insert, and the find is asked again.
    #
    #   Janela::Frame.for(account, :overview)
    #   Janela::Frame.for(queue, :analytics) { |frame| frame.name = "#{queue.name} analytics" }
    def self.for(owner, key, &block)
      key = key.to_s
      find_or_create_by!(owner: owner, key: key) do |frame|
        frame.name = key.humanize
        block&.call(frame)
      end
    rescue ActiveRecord::RecordNotUnique
      find_by!(owner: owner, key: key)
    end

    # Positions are kept contiguous so that moving a pane has no gap to fall
    # into and a new pane's position is never a hole. Called after a pane is
    # removed rather than on read, because reading a frame is the common case.
    def resequence_panes!
      panes.order(:position).each_with_index do |pane, index|
        pane.update_columns(position: index + 1) unless pane.position == index + 1
      end
    end

    # This frame's permanent filter, if the pane asking is over the model it
    # names; empty for any other model, because the condition was never
    # claimed to be about it (ADR 043).
    def default_for(model)
      return {} if default_model.blank? || default_model != model.model_name.route_key

      default_where.to_h
    end

    private
      def default_where_matches_default_model
        return if default_model.blank? && default_where.blank?
        return errors.add(:default_where, "cannot be set without default_model") if default_model.blank?
        return errors.add(:default_model, "cannot be set without default_where") if default_where.blank?

        definition = Janela.definition!(default_model)
        # A no-op relation: this checks the condition's shape against the
        # model's declared dimensions (ADR 025), and never has to touch a row
        # to do it.
        definition.narrow(definition.model.none, default_where)
      rescue Janela::NotFound
        errors.add(:default_model, "must be a model with a janela block")
      rescue Janela::BadRequest => e
        errors.add(:default_where, e.message)
      end
  end
end
