Rails.application.routes.draw do
  # Not pages, and not in a language: the platform and the crawlers ask for these
  # at one address.
  get "up" => "rails/health#show", as: :rails_health_check
  get "version", to: "version#show"
  get "manifest", to: "rails/pwa#manifest", as: :pwa_manifest
  get "robots.txt", to: "seo#robots"
  get "sitemap", to: "seo#sitemap", as: :sitemap, defaults: { format: :xml }

  # English at the root and Brazilian Portuguese under /pt-BR, one address per
  # language so a link carries the language and a search engine can see both
  # (ADR 061). The constraint means any other prefix is a 404, not a locale.
  scope "(:locale)", locale: /pt-BR/ do
    root "pages#home"
    get "orders", to: "dashboards#show", as: :orders
    # The same dashboard narrowed to one status by the host rather than by the
    # reader, which no click can take off (ADR 040).
    get "orders/status/:status", to: "dashboards#show", as: :orders_for_status
    get "gallery", to: "gallery#show", as: :gallery
    get "visits", to: "visits#show", as: :visits
    get "vitral", to: "pages#vitral", as: :vitral
    get "name", to: "pages#name", as: :the_name
    get "docs", to: "docs#index"
    # The naming guide is no longer listed as a document: /name is the page that
    # tells that story, on top of the same markdown (see Doc::UNLISTED). Anyone
    # holding the old documentation link lands there rather than on a 404.
    get "docs/naming", to: redirect { |params, _request| params[:locale] ? "/#{params[:locale]}/name" : "/name" }
    get "docs/:slug", to: "docs#show", as: :doc, constraints: { slug: /[a-z0-9-]+/ }
    resources :snapshots, only: :show
    resources :frames, only: :show
    get "frames/:id/status/:status", to: "frames#show", as: :frame_for_status
    mount Janela::Engine => "/dashboards"
  end
end
