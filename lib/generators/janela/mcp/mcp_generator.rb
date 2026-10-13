require "json"
require "rails/generators"

module Janela
  module Generators
    # Writes the server an agent reaches Janela::Tools through, and the entry
    # MCP clients read to find it (ADR 057). Both belong to the host from then
    # on. Janela edits nothing else: the Gemfile is told about, not changed.
    class McpGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)
      desc "Writes bin/janela-mcp and a .mcp.json entry so an agent can arrange dashboards."

      def write_server
        if File.exist?(File.join(destination_root, SERVER))
          say_status :exist, "#{SERVER} already there, left alone", :blue
        else
          template "janela-mcp.tt", SERVER
          chmod SERVER, 0o755
        end
      end

      def register_with_clients
        path = File.join(destination_root, ".mcp.json")
        config = File.exist?(path) ? JSON.parse(File.read(path)) : {}
        servers = (config["mcpServers"] ||= {})

        if servers.key?("janela")
          say_status :exist, ".mcp.json already has a janela server, left alone", :blue
        else
          servers["janela"] = { "command" => "bundle", "args" => [ "exec", SERVER ] }
          create_file ".mcp.json", JSON.pretty_generate(config) + "\n", force: true
        end
      end

      def say_what_is_next
        say
        say %(Add gem "mcp" to your Gemfile and bundle: the server uses the official Ruby SDK, and Janela depends on no MCP library.) unless mcp_bundled?
        say "Then open #{SERVER} and write the scope: who the agent acts for, and what that caller may read."
        say "Until you do, every tool refuses to read. Start it with: bundle exec #{SERVER}"
        say "Guide: docs/agents.md"
      end

      private
        SERVER = "bin/janela-mcp".freeze

        def mcp_bundled?
          Gem.loaded_specs.key?("mcp")
        end
    end
  end
end
