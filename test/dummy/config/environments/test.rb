Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = ENV["CI"].present?
  config.consider_all_requests_local = true
  config.cache_store = :null_store
  config.action_dispatch.show_exceptions = :rescuable
  config.action_controller.allow_forgery_protection = false
  config.action_controller.raise_on_missing_callback_actions = true
  config.active_support.deprecation = :stderr
  # A key that is in no language file is a typo, and it should not render as
  # "translation missing" on a page (ADR 061).
  config.i18n.raise_on_missing_translations = true
  config.action_dispatch.show_exceptions = :none if ENV["RAILS_SYSTEM_TESTING_SCREENSHOT"]
end
