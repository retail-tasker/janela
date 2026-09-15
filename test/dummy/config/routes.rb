Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root "dashboards#show"
  get "version", to: "version#show"
  resources :snapshots, only: :show
  mount Janela::Engine => "/dashboards"
end
