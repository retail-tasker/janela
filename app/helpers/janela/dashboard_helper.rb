module Janela
  module DashboardHelper
    def janela_dashboard(&block)
      tag.div(data: { controller: "janela--dashboard" }, &block)
    end

    def janela_pane(model, measure, by: nil, as: :table, granularity: nil)
      query = { as: (as unless as.to_s == "table"), granularity: granularity }.compact
      src = janela_routes.pane_path(model.model_name.route_key, measure, by, **query)

      turbo_frame_tag Pane.frame_id(model: model, measure: measure, by: by, as: as, granularity: granularity),
        src: src,
        loading: :lazy,
        data: { janela__dashboard_target: "pane", janela_src: src }
    end

    private
      # The host chooses where and under what name the engine is mounted, so
      # the route proxy is looked up rather than assumed to be `janela`.
      def janela_routes
        @janela_routes ||= begin
          mount = Rails.application.routes.routes.find { |route| route.app.respond_to?(:app) && route.app.app == Janela::Engine }
          raise Error, "Janela::Engine is not mounted in the host application's routes" unless mount

          public_send(mount.name)
        end
      end
  end
end
