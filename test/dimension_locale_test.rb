require "test_helper"

# ADR 061: a time pane's month label is written in the reader's language when the
# host has that language's month names, and in English when it has not, so a host
# that never set a locale sees exactly what it did.
class DimensionLocaleTest < ActiveSupport::TestCase
  setup { @time = Time.utc(2026, 10, 14, 9) }

  def month_label
    Janela::Dimension::LABELS.fetch("month").call(@time)
  end

  test "a month is written in English by default" do
    I18n.with_locale(:en) { assert_equal "Oct 2026", month_label }
  end

  test "a month is written in Portuguese when the host has Portuguese month names" do
    I18n.with_locale(:"pt-BR") { assert_equal "out 2026", month_label }
  end

  test "a locale with no month names falls back to English rather than raising" do
    available = I18n.available_locales
    I18n.available_locales = available + [ :xx ]
    I18n.backend.store_translations(:xx, date: {})
    I18n.with_locale(:xx) { assert_equal "Oct 2026", month_label }
  ensure
    I18n.available_locales = available
  end
end
