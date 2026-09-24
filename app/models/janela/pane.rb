module Janela
  # One pane of a frame, as data: where it sits, how wide it is, and what it
  # shows (ADR 012). A row may only name a measure and a dimension the model's
  # janela block declares, so an analyst arranges what is shown and cannot
  # invent a query or reach a model nobody exposed.
  class Pane < ActiveRecord::Base
    SPANS = (1..12).freeze
    LIMITS = (1..1000).freeze
    # A form cannot offer a thousand options, and these are the row counts a
    # dashboard actually asks for. Any limit inside LIMITS is still valid.
    OFFERED_LIMITS = [ 5, 10, 20, 50, 100 ].freeze

    # What a pane holds (ADR 039). A query is today's pane. Text is words an
    # analyst writes, escaped. A partial is markup a host wrote in code, which
    # an analyst places by name and hands the same words to.
    KINDS = %w[query text partial].freeze
    # Outside app/views/janela/ on purpose: a host view at an engine's path
    # replaces the engine's own, and janela/panes/ holds the engine's forms.
    CONTENT_PARTIALS = "janela_content"
    PARTIAL_NAME = /\A[a-z0-9_]+\z/
    # A path on this site: one slash, then not a second. A scheme or a
    # protocol relative // would send a reader anywhere under the host's name.
    SITE_PATH = %r{\A/(?!/)}

    belongs_to :frame

    before_validation :assign_position, on: :create

    validates :position, presence: true
    validates :kind, inclusion: { in: KINDS }
    validates :span, inclusion: { in: SPANS }
    validates :limit, inclusion: { in: LIMITS }, allow_nil: true
    validates :measure, presence: true, if: :query?
    validate :declared_by_a_janela_block, if: :query?
    validate :holds_no_query, unless: :query?
    validates :heading, presence: true, if: -> { text? && body.blank? }
    validates :link, format: { with: SITE_PATH, message: "must be a path on this site, starting with /" }, allow_blank: true
    validate :names_a_content_partial, if: :partial?

    # The partials a host has written for analysts to place, by name.
    def self.content_partials
      ActionController::Base.view_paths.flat_map do |path|
        Dir.glob(File.join(path.to_s, CONTENT_PARTIALS, "_*.html.erb")).map { |file| File.basename(file, ".html.erb").delete_prefix("_") }
      end.select { |name| name.match?(PARTIAL_NAME) }.uniq.sort
    end

    def query?
      kind == "query"
    end

    def text?
      kind == "text"
    end

    def partial?
      kind == "partial"
    end

    def partial_path
      "#{CONTENT_PARTIALS}/#{partial}"
    end

    # The DOM id is the row, not the query it runs: two rows in one frame may
    # show the same measure by the same dimension, and a fingerprint of the
    # query would give them the same turbo frame for Turbo to replace (ADR 014).
    def turbo_frame_id
      "janela_pane_#{id}"
    end

    # renderer: overrides what the row asked for, because a renderer is a
    # viewing choice and a surface without a chart runtime shows a table
    # instead (ADR 018).
    def query(filters: {}, fixed: {}, renderer: self.renderer)
      Query.new(definition: definition, measure: measure.to_sym, dimension: dimension.presence&.to_sym,
                renderer: renderer, granularity: granularity, limit: limit, filters: filters, fixed: fixed,
                title: title)
    end

    # The row's own words, for a list or a heading. Built from the columns
    # rather than from a query, because an editing page has to render even if
    # a janela block has since lost the dimension this row names.
    def label
      return content_label unless query?
      return title if title.present?

      dimension.present? ? "#{measure.humanize} by #{dimension.humanize}" : measure.to_s.humanize
    end

    # Arranging the window is the point of the editing surface, and a number
    # field is not arranging, so a pane swaps places with its neighbour.
    # Written without validations: the swap passes through a moment where two
    # panes share a position, and neither row's own data is being changed.
    def move_up
      swap_with(panes_above.last)
    end

    def move_down
      swap_with(panes_below.first)
    end

    def chart?
      Query::RENDERERS.include?(renderer.to_s) && renderer.to_s != "table"
    end

    def definition
      Janela.definition!(model)
    end

    private
      def panes_above
        frame.panes.where(position: ...position).order(:position)
      end

      def panes_below
        frame.panes.where(position: (position + 1)..).order(:position)
      end

      def swap_with(other)
        return false if other.nil?

        transaction do
          mine = position
          update_columns(position: other.position, updated_at: Time.current)
          other.update_columns(position: mine, updated_at: Time.current)
          frame.touch
        end
        true
      end

      def content_label
        return heading if heading.present?
        return partial.humanize if partial?

        body.to_s.truncate(40)
      end

      # A row is one thing or the other, so the database never holds half a
      # query that nothing will run.
      def holds_no_query
        %i[model measure dimension granularity].each do |column|
          errors.add(column, "belongs to a query pane, not a #{kind} one") if self[column].present?
        end
      end

      def names_a_content_partial
        return if partial.to_s.match?(PARTIAL_NAME) && self.class.content_partials.include?(partial)

        errors.add(:partial, "must name a partial in app/views/#{CONTENT_PARTIALS}/")
      end

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
