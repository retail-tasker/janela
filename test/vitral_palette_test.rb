require "test_helper"

# ADR 026: the palette a bar takes is part of the theme. Vitral set only the
# accent, so the first bar was stained glass and the other seven were Janela's
# neutral defaults (#67).
class VitralPaletteTest < ActiveSupport::TestCase
  VITRAL = File.read(Janela::Engine.root.join("app/assets/stylesheets/vitral.css"))
  JANELA = File.read(Janela::Engine.root.join("app/assets/stylesheets/janela.css"))

  # Run through the dataviz palette checker on 2026-10-01 as one ordered set:
  # lightness band, chroma floor, adjacent colour vision separation 12.4 (target
  # 8) and adjacent normal vision separation 15.8 (floor 15). The order is what
  # keeps neighbours apart, so it is part of the contract and a reorder has to
  # be re-checked. An earlier saturated set passed too and was rejected by eye:
  # it read as a rainbow on the pale tiles.
  VALIDATED = %w[#608fcb #56ab81 #a492da #91507d #be774e #159da9 #c29e51 #994b59].freeze

  def declared(css, property)
    css[/#{Regexp.escape(property)}:\s*([^;]+);/, 1]&.strip
  end

  test "vitral sets all eight series colours and the neutral" do
    (1..8).each { |step| assert declared(VITRAL, "--janela-series-#{step}"), "--janela-series-#{step}" }
    assert declared(VITRAL, "--janela-series-other")
  end

  test "slot 1 is a softer blue of vitral's own, and the accent stays the stronger one" do
    assert_equal "#608fcb", declared(VITRAL, "--janela-series-1")
    assert_equal "rgb(40, 110, 205)", declared(VITRAL, "--janela-accent")
    assert_equal "var(--janela-accent)", declared(JANELA, "--janela-series-1")
  end

  test "the set is the one that passed the checker, in the order it passed in" do
    chosen = (1..8).map { |step| declared(VITRAL, "--janela-series-#{step}").downcase }

    assert_equal VALIDATED, chosen
  end

  test "it is not Janela's neutral set under another name" do
    (2..8).each do |step|
      assert_not_equal declared(JANELA, "--janela-series-#{step}").downcase, declared(VITRAL, "--janela-series-#{step}").downcase
    end
  end

  # A dark lead outline was tried and rejected as heavy (#67). The gap between
  # slices is Janela's own, the page's colour, and the theme leaves it alone.
  test "vitral leaves the gap between ring slices to Janela" do
    assert_no_match(/janela-ring-slice/, VITRAL)
    assert_no_match(/vitral-lead/, VITRAL)
  end

  test "the neutral is not one of the eight, so a ninth category is not mistaken for one" do
    assert_not_includes VALIDATED, declared(VITRAL, "--janela-series-other").downcase
  end
end
