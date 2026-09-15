Janela::Engine.routes.draw do
  segment = /[a-z0-9_]+/

  # Frames sit at the mount root and are drawn before the pane grammar, with a
  # numeric constraint: no model's route key is all digits, so /3 is a frame
  # and /orders/revenue is a pane, with nothing to disambiguate (ADR 014).
  resources :frames, path: "", only: [ :index, :show ], constraints: { id: /\d+/ } do
    resources :panes, only: :show, constraints: { id: /\d+/, frame_id: /\d+/ }
  end

  get "snapshots/:snapshot_id/:model/:measure(/:dimension)", to: "snapshot_queries#show", as: :snapshot_pane,
    constraints: { snapshot_id: /\d+/, model: segment, measure: segment, dimension: segment }

  get ":model/:measure(/:dimension)", to: "queries#show", as: :pane,
    constraints: { model: segment, measure: segment, dimension: segment }
end
