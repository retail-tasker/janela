Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root "pages#home"
  get "orders", to: "dashboards#show", as: :orders
  get "gallery", to: "gallery#show", as: :gallery
  get "name", to: "pages#name", as: :the_name
  get "docs", to: "docs#index"
  # The naming guide is no longer listed as a document: /name is the page that
  # tells that story, on top of the same markdown (see Doc::UNLISTED). Anyone
  # holding the old documentation link lands there rather than on a 404.
  get "docs/naming", to: redirect("/name")
  get "docs/:slug", to: "docs#show", as: :doc, constraints: { slug: /[a-z0-9-]+/ }
  get "version", to: "version#show"
  resources :snapshots, only: :show
  resources :frames, only: :show
  mount Janela::Engine => "/dashboards"
end
