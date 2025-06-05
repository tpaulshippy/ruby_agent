# frozen_string_literal: true

require 'ruby_llm/mcp'
require 'json'
require 'pathname'

module MCP
  # Client provides factory methods for creating MCP clients from various configurations
  class Client
    def self.sse_client(url)
      RubyLLM::MCP.client(
        name: 'coding-agent-mcp',
        transport_type: 'sse',
        config: {
          url: url
        }
      )
    end

    def self.stdio_client(command, args = [], env = {})
      RubyLLM::MCP.client(
        name: 'coding-agent-mcp',
        transport_type: 'stdio',
        config: {
          command: command,
          args: args,
          env: env
        }
      )
    end

    def self.from_json_file(file_path = nil)
      file_path ||= File.join(Dir.pwd, 'mcp.json')
      return nil unless File.exist?(file_path)

      begin
        # Remove comments from the JSON file (// comments are not valid in standard JSON)
        json_content = File.read(file_path).gsub(%r{//.*$}, '')
        config = JSON.parse(json_content)

        return nil unless config['mcpServers'] && !config['mcpServers'].empty?

        # Use the first server definition by default, or a specific one if provided
        _, server_config = config['mcpServers'].first

        if server_config['url']
          sse_client(server_config['url'])
        elsif server_config['command']
          stdio_client(
            server_config['command'],
            server_config['args'] || [],
            server_config['env'] || {}
          )
        end
      rescue JSON::ParserError => e
        puts "Error parsing mcp.json: #{e.message}"
        nil
      end
    end
  end
end
