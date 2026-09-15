module Janela
  # Janela's own pages, so a host can install the gem and navigate the same
  # day (ADR 013), and the analyst's editing surface, as conventional Rails
  # CRUD rather than a canvas (ADR 012, ADR 014). Every action reads through
  # the host's scope rather than Frame.find, so another tenant's frame is a
  # 404 to edit as well as to read.
  class FramesController < ApplicationController
    before_action :set_frame, only: %i[show edit update destroy]

    def index
      @frames = janela_scope(Frame).includes(:panes).order(:name)
    end

    def show
    end

    def new
      @frame = Frame.new
    end

    def edit
    end

    def create
      @frame = Frame.new(frame_params)
      @frame.owner = janela_frame_owner

      if @frame.save
        redirect_to edit_frame_path(@frame), notice: t("janela.frames.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @frame.update(frame_params)
        redirect_to frame_path(@frame), notice: t("janela.frames.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @frame.destroy
      redirect_to frames_path, notice: t("janela.frames.destroyed")
    end

    private
      def set_frame
        @frame = janela_scope(Frame).find(params.require(:id))
      end

      def frame_params
        params.expect(frame: [ :name, :columns, :gap ])
      end
  end
end
