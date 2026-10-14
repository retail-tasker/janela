# The demo's routes sit under an optional /pt-BR prefix (ADR 061). Called with a
# positional argument and no locale key, doc_path("agents") fills the locale
# segment instead of the slug, so the key is always there: nil, which is
# English. Set on the route set, which an integration test merges into its URL
# options. In an initializer because routes.rb is loaded before Rails finishes
# configuring the route set, and a setting made there did not survive.
Rails.application.routes.default_url_options[:locale] = nil
