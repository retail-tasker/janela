require "test_helper"
require "rails/generators/test_case"
require "generators/janela/mcp/mcp_generator"

# ADR 057: a host is given the server file the agents guide describes, and owns
# it from then on. The generator writes two things and edits nothing else.
class McpGeneratorTest < Rails::Generators::TestCase
  tests Janela::Generators::McpGenerator
  destination File.expand_path("tmp/mcp_generator", __dir__)
  setup :prepare_destination

  test "it writes an executable server and an entry the clients read" do
    run_generator

    assert_file "bin/janela-mcp"
    assert File.executable?(File.join(destination_root, "bin/janela-mcp"))
    config = JSON.parse(File.read(File.join(destination_root, ".mcp.json")))
    assert_equal "bundle", config.dig("mcpServers", "janela", "command")
    assert_equal %w[exec bin/janela-mcp], config.dig("mcpServers", "janela", "args")
  end

  test "an existing mcp config keeps its other servers" do
    File.write(File.join(destination_root, ".mcp.json"), { mcpServers: { other: { command: "x" } } }.to_json)

    run_generator

    config = JSON.parse(File.read(File.join(destination_root, ".mcp.json")))
    assert_equal %w[janela other], config["mcpServers"].keys.sort
  end

  test "a server the host already wrote is left alone, and so is its entry" do
    FileUtils.mkdir_p(File.join(destination_root, "bin"))
    File.write(File.join(destination_root, "bin/janela-mcp"), "# mine\n")
    File.write(File.join(destination_root, ".mcp.json"), { mcpServers: { janela: { command: "mine" } } }.to_json)

    output = run_generator

    assert_equal "# mine\n", File.read(File.join(destination_root, "bin/janela-mcp"))
    assert_equal "mine", JSON.parse(File.read(File.join(destination_root, ".mcp.json"))).dig("mcpServers", "janela", "command")
    assert_match(/already/, output)
  end

  test "it never edits the Gemfile, and says what to add when mcp is not in the bundle" do
    File.write(File.join(destination_root, "Gemfile"), "source \"https://rubygems.org\"\n")
    spec = Gem.loaded_specs.delete("mcp")
    output = run_generator

    assert_equal "source \"https://rubygems.org\"\n", File.read(File.join(destination_root, "Gemfile"))
    assert_match(/gem "mcp"/, output)
  ensure
    Gem.loaded_specs["mcp"] = spec if spec
  end

  # The scope is the one thing the generator cannot know, so the file raises
  # until the host writes it, and an unedited file reads nothing (ADR 032).
  test "a server file the host has not edited refuses to read" do
    run_generator
    source = File.read(File.join(destination_root, "bin/janela-mcp"))

    assert_match(/Janela::Unscoped/, source)
    assert_match(/Rails\.env\.development\?/, source)
  end

  # The adapter in the file and the adapter in the guide are the same text, so
  # neither can drift from the other (ADR 010, ADR 053).
  test "the generated adapter is the one docs/agents.md shows" do
    run_generator
    source = File.read(File.join(destination_root, "bin/janela-mcp"))
    guide = File.read(Janela::Engine.root.join("docs/agents.md"))
    adapter = guide[/^```ruby\n(def janela_server.*?^end)\n```/m, 1]

    assert adapter, "docs/agents.md should still show def janela_server"
    assert_includes source, adapter
  end
end
