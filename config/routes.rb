Janela::Engine.routes.draw do
  segment = /[a-z0-9_]+/

  # Frames sit at the mount root and are drawn before the pane grammar, with a
  # numeric constraint: no model's route key is all digits, so /3 is a frame
  # and /orders/revenue is a pane, with nothing to disambiguate (ADR 014).
  resources :frames, path: "", constraints: { id: /\d+/ } do
    # No index: a frame's own edit page is the list of its panes.
    resources :panes, except: :index, constraints: { id: /\d+/, frame_id: /\d+/ } do
      member do
        patch :move_up
        patch :move_down
      end
    end
  end

  get "snapshots/:snapshot_id/:model/:measure(/:dimension)", to: "snapshot_queries#show", as: :snapshot_pane,
    constraints: { snapshot_id: /\d+/, model: segment, measure: segment, dimension: segment }

  get ":model/:measure(/:dimension)", to: "queries#show", as: :pane,
    constraints: { model: segment, measure: segment, dimension: segment }
end
