# Which language a page is in and how to get to the same page in the other
# (ADR 061). English is the root and Brazilian Portuguese is under /pt-BR, so
# the language is in the address, where a link, a search engine and a person
# can all see it, and no cookie is needed to remember it.
module LocaleHelper
  LANGUAGES = { en: "English", "pt-BR": "Português" }.freeze
  PREFIX = %r{\A/pt-BR(?=/|\z)}

  def other_locale
    I18n.locale == :en ? :"pt-BR" : :en
  end

  def language_name(locale)
    LANGUAGES.fetch(locale.to_sym)
  end

  # This page's path in the given language, keeping any filter on it.
  def path_in(locale, query: true)
    path = request.path.sub(PREFIX, "")
    path = "/" if path.empty?
    path = path == "/" ? "/pt-BR" : "/pt-BR#{path}" if locale.to_s == "pt-BR"
    query && request.query_string.present? ? "#{path}?#{request.query_string}" : path
  end

  def absolute_path_in(locale)
    "#{request.base_url}#{path_in(locale, query: false)}"
  end

  # A page says it is translated, and every other page is English however the
  # menu around it reads.
  def translated_page?
    content_for?(:translated)
  end

  # Janela's own pages are in the reader's language already, so they are not
  # "still English", and neither is a page that has been translated.
  def locale_notice?
    I18n.locale != I18n.default_locale && !translated_page? && !controller.is_a?(Janela::ApplicationController)
  end

  def open_graph_locale
    I18n.locale == :en ? "en_US" : "pt_BR"
  end
end
