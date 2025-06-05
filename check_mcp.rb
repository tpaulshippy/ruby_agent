#!/usr/bin/env ruby
# frozen_string_literal: true

# This script checks if the MCP server configuration is valid and can connect

Dir.chdir(__dir__) do
  require 'bundler/setup'
  require 'ruby_llm'
  require 'ruby_llm/mcp'
  require_relative 'src/mcp/client'
end

# NOTE: We're skipping the complex parameters support as it appears
# to have issues with the current version of the gem

puts 'Checking MCP configuration from mcp.json...'
mcp_client = MCP::Client.from_json_file
if mcp_client
  puts '✅ MCP client connected successfully using mcp.json'
  puts 'Available MCP tools:'
  mcp_client.tools.each do |tool|
    puts "  - #{tool.name}: #{tool.description}"
  end
else
  puts '❌ Failed to connect to MCP server using mcp.json'

  # Try from env as fallback
  puts "\nTrying environment variables as fallback..."
  mcp_client = MCP::Client.from_env
  if mcp_client
    puts '✅ MCP client connected successfully using environment variables'
    puts 'Available MCP tools:'
    mcp_client.tools.each do |tool|
      puts "  - #{tool.name}: #{tool.description}"
    end
  else
    puts '❌ Failed to connect to MCP server using environment variables'
    puts "\nPlease check your mcp.json configuration or environment variables."
  end
end
