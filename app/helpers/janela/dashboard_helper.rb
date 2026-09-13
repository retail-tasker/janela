module Janela
  module DashboardHelper
    def janela_dashboard(&block)
      tag.div(data: { controller: "janela--dashboard" }, &block)
    end

    def janela_visual(model, measure, by:)
      src = janela.visual_path(model: model.name, measure: measure, by: by)

      turbo_frame_tag Visual.frame_id(model: model.name, measure: measure, by: by),
        src: src,
        loading: :lazy,
        data: { janela__dashboard_target: "visual", janela_src: src }
    end
  end
end
