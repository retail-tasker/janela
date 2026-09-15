Janela::Engine.routes.draw do
  segment = /[a-z0-9_]+/
  get ":model/:measure(/:dimension)", to: "panes#show", as: :pane,
    constraints: { model: segment, measure: segment, dimension: segment }
end
