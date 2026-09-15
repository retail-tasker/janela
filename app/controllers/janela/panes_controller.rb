module Janela
  # One pane of a frame: rendered from its row so the row's own title reaches
  # the response (ADR 014), and edited as a nested resource (ADR 012).
  class PanesController < ApplicationController
    before_action :set_frame
    before_action :set_pane, only: %i[show edit update destroy move_up move_down]

    def show
      @query = @pane.query(filters: filters)
      @result = @query.result(on: janela_scope(@query.model))
    end

    # Two steps, because the engine's pages have no JavaScript to refresh one
    # select from another: the first picks a model, the second offers exactly
    # that model's measures and dimensions (ADR 018).
    def new
      @pane = @frame.panes.build(model: params[:model], renderer: "table", span: 1)
      @definition = @pane.model.present? ? Janela.definition!(@pane.model) : nil
    end

    def edit
      @definition = @pane.definition
    end

    def create
      @pane = @frame.panes.build(pane_params)

      if @pane.save
        redirect_to edit_frame_path(@frame), notice: t("janela.panes.created")
      else
        @definition = @pane.model.present? ? Janela.definition!(@pane.model) : nil
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @pane.update(pane_params)
        redirect_to edit_frame_path(@frame), notice: t("janela.panes.updated")
      else
        @definition = @pane.definition
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
        params.expect(pane: [ :model, :measure, :dimension, :renderer, :granularity, :limit, :span, :title ])
      end
  end
end
