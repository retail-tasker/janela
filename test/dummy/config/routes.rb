Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root "pages#home"
  get "orders", to: "dashboards#show", as: :orders
  get "version", to: "version#show"
  resources :snapshots, only: :show
  resources :frames, only: :show
  mount Janela::Engine => "/dashboards"
end
