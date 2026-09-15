module Janela
  # One pane of a frame, as data: where it sits, how wide it is, and what it
  # shows (ADR 012). A row may only name a measure and a dimension the model's
  # janela block declares, so an analyst arranges what is shown and cannot
  # invent a query or reach a model nobody exposed.
  class Pane < ActiveRecord::Base
    SPANS = (1..12).freeze
    LIMITS = (1..1000).freeze

    belongs_to :frame

    before_validation :assign_position, on: :create

    validates :position, presence: true
    validates :measure, presence: true
    validates :span, inclusion: { in: SPANS }
    validates :limit, inclusion: { in: LIMITS }, allow_nil: true
    validate :declared_by_a_janela_block

    # The DOM id is the row, not the query it runs: two rows in one frame may
    # show the same measure by the same dimension, and a fingerprint of the
    # query would give them the same turbo frame for Turbo to replace (ADR 014).
    def turbo_frame_id
      "janela_pane_#{id}"
    end

    # renderer: overrides what the row asked for, because a renderer is a
    # viewing choice and a surface without a chart runtime shows a table
    # instead (ADR 018).
    def query(filters: {}, renderer: self.renderer)
      Query.new(definition: definition, measure: measure.to_sym, dimension: dimension.presence&.to_sym,
                renderer: renderer, granularity: granularity, limit: limit, filters: filters, title: title)
    end

    def chart?
      Query::RENDERERS.include?(renderer.to_s) && renderer.to_s != "table"
    end

    def definition
      Janela.definition!(model)
    end

    private
      def assign_position
        self.position ||= (frame&.panes&.maximum(:position) || 0) + 1
      end

      # A janela block can lose a measure or a dimension long after a row named
      # it, and the pane would then fail at render as a missing pane rather
      # than a bad row. Checked on save, and as errors rather than raising, so
      # the row is rejected with something a person can read (ADR 014).
      def declared_by_a_janela_block
        return errors.add(:model, "must be a model with a janela block") if model.blank?

        declaration = definition
        validate_measure(declaration) if measure.present?
        dimension_declaration = validate_dimension(declaration)
        validate_renderer
        validate_granularity(dimension_declaration)
      rescue Janela::Error
        errors.add(:model, "#{model.inspect} is not a janela model")
      end

      def validate_measure(declaration)
        return if declaration.measures.key?(measure.to_s.to_sym)

        errors.add(:measure, "#{measure.inspect} is not a measure of #{declaration.model}")
      end

      def validate_dimension(declaration)
        return if dimension.blank?

        declaration.dimensions.fetch(dimension.to_sym) do
          errors.add(:dimension, "#{dimension.inspect} is not a dimension of #{declaration.model}")
          nil
        end
      end

      def validate_renderer
        return if Query::RENDERERS.include?(renderer.to_s)

        errors.add(:renderer, "must be one of #{Query::RENDERERS.join(', ')}")
      end

      def validate_granularity(dimension_declaration)
        return if granularity.blank?

        unless Dimension::GRANULARITIES.include?(granularity)
          return errors.add(:granularity, "must be one of #{Dimension::GRANULARITIES.join(', ')}")
        end
        return if dimension_declaration.nil? || dimension_declaration.time?

        errors.add(:granularity, "only applies to a time dimension, and #{dimension} is not one")
      end
  end
end
