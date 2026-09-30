require "test_helper"
require "ostruct"

# #14. Believed: under Sprockets the engine's importmap pins are skipped with
# a log warning. Measured against a Sprockets host: the page raises
# AssetNotPrecompiledError, because the engine declared its stylesheets
# precompilable and never its JavaScript. The demo runs Propshaft, which has
# no precompile list, so nothing here can be seen from a real Sprockets app;
# this runs the engine's own initializer against a stand-in for one.
class EngineAssetsTest < ActiveSupport::TestCase
  # Spelled out here rather than read from the engine, so a change to what the
  # engine declares has to change this list too.
  JAVASCRIPT = %w[
    janela/frame_controller.js janela/chart_controller.js janela/vitral_controller.js janela/vendor/chart.js
  ].freeze

  test "a Sprockets host on importmap can precompile the JavaScript the engine pins" do
    precompile = run_initializer(precompile: [], importmap: true)

    assert_empty JAVASCRIPT - precompile
    assert_includes precompile, "janela.css"
  end

  test "every JavaScript path the engine declares is one its importmap pins" do
    pinned = File.read(Janela::Engine.root.join("config/importmap.rb")).scan(/to: "([^"]+)"/).flatten

    assert_empty JAVASCRIPT - pinned
  end

  # A host that bundles its JavaScript has no use for 200KB of Chart.js
  # compiled and digested by Sprockets, so the stylesheets stay and the
  # JavaScript does not follow.
  test "a Sprockets host that does not use importmap gets the stylesheets and no JavaScript" do
    precompile = run_initializer(precompile: [], importmap: false)

    assert_includes precompile, "janela.css"
    assert_empty precompile & JAVASCRIPT
  end

  test "a Propshaft host has no precompile list and nothing is added or raised" do
    assert_nothing_raised { assert_nil run_initializer(precompile: nil, importmap: true) }
  end

  private
    def run_initializer(precompile:, importmap:)
      assets = precompile ? OpenStruct.new(precompile: precompile) : Object.new
      config = OpenStruct.new(assets: assets)
      config.importmap = Object.new if importmap
      initializer = Janela::Engine.instance.initializers.find { |each| each.name == "janela.assets" }
      initializer.run(OpenStruct.new(config: config))
      precompile
    end
end
