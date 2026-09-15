Janela::Engine.routes.draw do
  segment = /[a-z0-9_]+/

  # Drawn first on purpose: a pane row's id is numeric, and the pane grammar
  # below would otherwise read frames/1 as the model "1" (ADR 014).
  resources :frames, path: "", only: [], constraints: { frame_id: /\d+/ } do
    resources :panes, only: :show, constraints: { id: /\d+/ }
  end

  get "snapshots/:snapshot_id/:model/:measure(/:dimension)", to: "snapshot_queries#show", as: :snapshot_pane,
    constraints: { snapshot_id: /\d+/, model: segment, measure: segment, dimension: segment }

  get ":model/:measure(/:dimension)", to: "queries#show", as: :pane,
    constraints: { model: segment, measure: segment, dimension: segment }
end
