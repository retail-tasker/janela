module Janela
  # One pane of a frame: rendered from its row so the row's own title reaches
  # the response (ADR 014), and edited as a nested resource (ADR 012).
  class PanesController < ApplicationController
    before_action :set_frame
    before_action :set_pane, only: %i[show edit update destroy move_up move_down]

    # A content pane has no query, so it has no URL to be fetched from.
    def show
      raise NotFound, "pane #{@pane.id} holds content, not a query" unless @pane.query?

      @query = @pane.query(filters: filters, fixed: fixed_filters)
      @result = @query.result(on: janela_scope(@query.model))
    end

    # Two steps, because the engine's pages have no JavaScript to refresh one
    # select from another: the first picks a model, the second offers exactly
    # that model's measures and dimensions (ADR 018).
    # Step one also offers words, and each partial the host wrote for them
    # (ADR 039), in the same list as the models, since each is a choice of
    # what the pane holds.
    def new
      @pane = build_pane(params[:model])
      @definition = @pane.query? && @pane.model.present? ? Janela.definition!(@pane.model) : nil
    end

    def edit
      @definition = @pane.definition if @pane.query?
    end

    def create
      @pane = @frame.panes.build(pane_params)

      if @pane.save
        redirect_to edit_frame_path(@frame), notice: t("janela.panes.created")
      else
        @definition = @pane.query? && @pane.model.present? ? Janela.definition!(@pane.model) : nil
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @pane.update(pane_params)
        redirect_to edit_frame_path(@frame), notice: t("janela.panes.updated")
      else
        @definition = @pane.definition if @pane.query?
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @pane.destroy
      @frame.resequence_panes!
      redirect_to edit_frame_path(@frame), notice: t("janela.panes.destroyed")
    end

    def move_up
      @pane.move_up
      redirect_to edit_frame_path(@frame)
    end

    def move_down
      @pane.move_down
      redirect_to edit_frame_path(@frame)
    end

    private
      # Through the host's scope rather than Pane.find, so a frame belonging to
      # another tenant is a 404 for every action (ADR 014).
      def set_frame
        @frame = janela_scope(Frame).find(params.require(:frame_id))
      end

      def set_pane
        @pane = @frame.panes.find(params.require(:id))
      end

      def pane_params
        params.expect(pane: [ :kind, :model, :measure, :dimension, :renderer, :granularity, :limit, :span, :title,
                              :heading, :body, :link, :partial ])
      end

      def build_pane(choice)
        case choice.to_s
        when "text" then @frame.panes.build(kind: "text", span: 1)
        when /\Apartial:(.+)\z/ then @frame.panes.build(kind: "partial", partial: $1, span: 1)
        else @frame.panes.build(model: choice, renderer: "table", span: 1)
        end
      end
  end
end
