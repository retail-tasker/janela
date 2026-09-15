Rails.application.routes.draw do
  root "dashboards#show"
  get "version", to: "version#show"
  resources :snapshots, only: :show
  mount Janela::Engine => "/dashboards"
end
