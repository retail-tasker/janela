module Janela
  module DashboardHelper
    # The page URL carries the dashboard's filters as q[...] (ADR 008), so a
    # shared link renders filtered before any JavaScript runs.
    def janela_dashboard(&block)
      tag.div(data: { controller: "janela--dashboard", janela__dashboard_filters_value: janela_page_filters.to_json }, &block)
    end

    def janela_pane(model, measure, by: nil, as: :table, granularity: nil, limit: nil)
      query = { as: (as unless as.to_s == "table"), granularity: granularity, limit: limit }.compact
      base = janela_routes.pane_path(model.model_name.route_key, measure, by, **query)
      src = janela_page_filters.empty? ? base : janela_routes.pane_path(model.model_name.route_key, measure, by, **query, q: janela_page_filters)

      turbo_frame_tag Pane.frame_id(model: model, measure: measure, by: by, as: as, granularity: granularity, limit: limit),
        src: src,
        loading: :lazy,
        data: { janela__dashboard_target: "pane", janela_src: base }
    end

    # A pane as it was when the snapshot was taken: same shape as janela_pane,
    # not part of the live dashboard's filter state (ADR 009).
    def janela_snapshot_pane(snapshot, model, measure, by: nil, as: :table, granularity: nil, limit: nil)
      query = { as: (as unless as.to_s == "table"), granularity: granularity, limit: limit }.compact
      src = janela_routes.snapshot_pane_path(snapshot, model.model_name.route_key, measure, by, **query)

      turbo_frame_tag Pane.frame_id(model: model, measure: measure, by: by, as: as, granularity: granularity, limit: limit, snapshot: snapshot),
        src: src, loading: :lazy
    end

    private
      def janela_page_filters
        @janela_page_filters ||= begin
          q = request.query_parameters["q"]
          q.is_a?(Hash) ? q.sort.to_h : {}
        end
      end

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
