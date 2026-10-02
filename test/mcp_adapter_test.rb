require "test_helper"
require "mcp"

# The adapter the agents guide shows, run as written (ADR 010: every sample is
# executable, ADR 053). Janela depends on no MCP library; this is what a host
# using the official Ruby SDK writes, and it is here so it cannot drift.
class McpAdapterTest < ActiveSupport::TestCase
  # --- the sample in docs/agents.md starts here ---
  def janela_server(write: false)
    tools = Janela::Tools.all(write: write).map do |tool|
      MCP::Tool.define(name: tool.name, description: tool.description, input_schema: tool.input_schema,
                       annotations: { read_only_hint: tool.read_only }) do |server_context:, **arguments|
        # The scope is built per call, because who is asking is known only now.
        scope = ->(model) { server_context[:scope].call(model) }
        result = Janela::Tools.new(scope: scope, write: write).call(tool.name, arguments)
        MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
      rescue Janela::Error => error
        MCP::Tool::Response.new([ { type: "text", text: error.message } ], error: true)
      end
    end

    MCP::Server.new(name: "janela", tools: tools, server_context: { scope: yield })
  end
  # --- and ends here ---

  setup do
    acme = customers(:acme)
    @scope = ->(model) { model == Janela::Frame ? model.where(owner: acme) : model.all }
  end

  def call(server, name, arguments = {})
    response = server.handle({ jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: name, arguments: arguments } })
    result = response.fetch(:result)
    [ result[:isError], JSON.parse(result[:content].first[:text]) ]
  rescue JSON::ParserError
    [ result[:isError], result[:content].first[:text] ]
  end

  test "the registered tools read a frame through the scope the host built for this call" do
    server = janela_server { @scope }

    error, listed = call(server, "list_frames")

    assert_not error
    assert_includes listed["frames"].map { |frame| frame["name"] }, "Orders"
    assert_not_includes listed["frames"].map { |frame| frame["name"] }, "Globex only"
  end

  test "a refusal reaches the agent as the tool's own error, not a crash" do
    server = janela_server(write: true) { @scope }

    error, message = call(server, "add_pane", frame_id: janela_frames(:orders).id, model: "orders", measure: "nonsense")

    assert error
    assert_includes message, %(Measure "nonsense" is not a measure of Order)
  end

  test "a read-only server offers no write tool" do
    names = janela_server { @scope }.handle({ jsonrpc: "2.0", id: 1, method: "tools/list" }).dig(:result, :tools).map { |tool| tool[:name] }

    assert_equal %w[describe_vocabulary get_frame list_frames read_pane], names.sort
  end
end
