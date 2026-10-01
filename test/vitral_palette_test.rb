require "test_helper"

# ADR 026: the palette a bar takes is part of the theme. Vitral set only the
# accent, so the first bar was stained glass and the other seven were Janela's
# neutral defaults (#67).
class VitralPaletteTest < ActiveSupport::TestCase
  VITRAL = File.read(Janela::Engine.root.join("app/assets/stylesheets/vitral.css"))
  JANELA = File.read(Janela::Engine.root.join("app/assets/stylesheets/janela.css"))

  # Run through the dataviz palette checker on 2026-10-01 as one ordered set with
  # the accent in the first place: lightness band, chroma floor, adjacent colour
  # vision separation 11.1 (target 8) and adjacent normal vision separation 20.5
  # (floor 15). The order is what keeps neighbours apart, so it is part of the
  # contract and a reorder has to be re-checked.
  VALIDATED = %w[#286ecd #c93c54 #7d5bd1 #1f9d6b #e6a117 #17a2b8 #ea7a28 #c64f9a].freeze

  def declared(css, property)
    css[/#{Regexp.escape(property)}:\s*([^;]+);/, 1]&.strip
  end

  test "vitral sets the second to eighth series colours and the neutral" do
    (2..8).each { |step| assert declared(VITRAL, "--janela-series-#{step}"), "--janela-series-#{step}" }
    assert declared(VITRAL, "--janela-series-other")
  end

  test "the first colour is the accent, not a restated copy of it" do
    assert_nil declared(VITRAL, "--janela-series-1"), "janela.css already points slot 1 at --janela-accent"
    assert_equal "var(--janela-accent)", declared(JANELA, "--janela-series-1")
    assert_equal "rgb(40, 110, 205)", declared(VITRAL, "--janela-accent")
  end

  test "the set is the one that passed the checker, in the order it passed in" do
    chosen = (2..8).map { |step| declared(VITRAL, "--janela-series-#{step}").downcase }

    assert_equal VALIDATED.drop(1), chosen
  end

  test "it is not Janela's neutral set under another name" do
    (2..8).each do |step|
      assert_not_equal declared(JANELA, "--janela-series-#{step}").downcase, declared(VITRAL, "--janela-series-#{step}").downcase
    end
  end

  test "the neutral is not one of the eight, so a ninth category is not mistaken for one" do
    assert_not_includes VALIDATED, declared(VITRAL, "--janela-series-other").downcase
  end
end
