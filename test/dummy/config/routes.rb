Rails.application.routes.draw do
  root "dashboards#show"
  mount Janela::Engine => "/janela"
end
