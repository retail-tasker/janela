Rails.application.routes.draw do
  root "dashboards#show"
  resources :snapshots, only: :show
  mount Janela::Engine => "/dashboards"
end
