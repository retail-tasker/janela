module Janela
  module FramesHelper
    # Two ways to supply the panes: a frame record renders itself from its
    # rows (ADR 012), or a block composes janela_pane calls by hand. The page
    # URL carries the filters as q[...] either way (ADR 008), so a shared link
    # renders filtered before any JavaScript runs.
    # charts: false renders a chart pane as its table, for a surface with no
    # chart runtime. The engine's own pages are the case (ADR 018).
    def janela_frame(frame = nil, charts: true, &block)
      return render("janela/frames/frame", frame: frame, filters: janela_page_filters, charts: charts) if frame

      tag.div(data: { controller: "janela--frame", action: janela_frame_actions,
                      janela__frame_filters_value: janela_page_filters.to_json }, &block)
    end

    # id: names the pane's frame instead of fingerprinting it from the query,
    # so a host that changes the query in place (a renderer, granularity or
    # limit control) keeps one stable frame for Turbo to reconcile into
    # rather than a different id every time the query changes (ADR 029).
    def janela_pane(model, measure, by: nil, as: :table, granularity: nil, limit: nil, id: nil)
      query = { as: (as unless as.to_s == "table"), granularity: granularity, limit: limit }.compact
      base = janela_routes.pane_path(model.model_name.route_key, measure, by, **query)
      src = janela_page_filters.empty? ? base : janela_routes.pane_path(model.model_name.route_key, measure, by, **query, q: janela_page_filters)

      turbo_frame_tag id || Query.turbo_frame_id(model: model, measure: measure, by: by, as: as, granularity: granularity, limit: limit),
        src: src,
        loading: :lazy,
        data: { janela__frame_target: "pane", janela_src: base }
    end

    # A pane as it was when the snapshot was taken: same shape as janela_pane,
    # not part of the live frame's filter state (ADR 009).
    def janela_snapshot_pane(snapshot, model, measure, by: nil, as: :table, granularity: nil, limit: nil)
      query = { as: (as unless as.to_s == "table"), granularity: granularity, limit: limit }.compact
      src = janela_routes.snapshot_pane_path(snapshot, model.model_name.route_key, measure, by, **query)

      turbo_frame_tag Query.turbo_frame_id(model: model, measure: measure, by: by, as: as, granularity: granularity, limit: limit, snapshot: snapshot),
        src: src, loading: :lazy
    end

    private
      # Wired once per frame, so a host asks a pane to go to a different query
      # by dispatching an event from anywhere inside rather than by reaching
      # for the controller itself (ADR 030).
      def janela_frame_actions
        "keydown.esc->janela--frame#clear janela--frame:repoint->janela--frame#repoint"
      end

      def janela_frame_classes(frame)
        [ "janela-frame", "janela-cols-#{frame.columns}", "janela-gap-#{frame.gap}" ]
      end

      # A frame rendered inline runs its queries in the host's own request, so
      # the same scope the engine's controllers apply is applied here.
      #
      # Asked of the controller rather than of self. A helper runs on the
      # view, and a view cannot see a private controller method, so asking
      # self made this disagree with the engine's controllers about whether
      # the host had defined anything: a host writing policy_scope the way
      # docs/multi-tenancy.md teaches was scoped on Janela's pages and
      # unscoped on its own. Pundit hosts were unaffected only because
      # Pundit::Helper happens to define a view side copy (#46).
      def janela_scope(model)
        controller.respond_to?(:policy_scope, true) ? controller.send(:policy_scope, model) : model.all
      end

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
