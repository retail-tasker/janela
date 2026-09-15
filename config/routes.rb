Janela::Engine.routes.draw do
  segment = /[a-z0-9_]+/

  get "snapshots/:snapshot_id/:model/:measure(/:dimension)", to: "snapshot_panes#show", as: :snapshot_pane,
    constraints: { snapshot_id: /\d+/, model: segment, measure: segment, dimension: segment }

  get ":model/:measure(/:dimension)", to: "panes#show", as: :pane,
    constraints: { model: segment, measure: segment, dimension: segment }
end
