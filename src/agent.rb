# frozen_string_literal: true

require 'ruby_llm'
require 'ruby_llm/mcp'
require_relative 'tools/read_file'
require_relative 'tools/list_files'
require_relative 'tools/edit_file'
require_relative 'tools/run_shell_command'
require_relative 'mcp/client'
require_relative 'token_tracker'

class Agent
  def initialize
    model_id = ENV.fetch('MODEL_ID', 'qwen3:14b')
    provider = ENV.fetch('PROVIDER', 'ollama')
    @chat = RubyLLM.chat(model: model_id, provider: provider, assume_model_exists: provider == 'ollama')
    @chat.with_instructions <<~INSTRUCTIONS
      Perform the tasks requested as quickly as possible.
      When you call a tool, tell me what tool you called.
    INSTRUCTIONS

    @token_tracker = TokenTracker.new

    tools = [
      Tools::ReadFile,
      Tools::ListFiles,
      Tools::EditFile,
      Tools::RunShellCommand
    ]

    mcp_client = MCP::Client.from_json_file || MCP::Client.from_env
    if mcp_client
      puts 'MCP client connected. Adding MCP tools...'
      tools.concat(mcp_client.tools)
    end

    @chat.with_tools(*tools)
  end

  def run
    puts "Chat with the agent. Type 'exit' to ... well, exit"
    puts "Special commands: '/tokens' (session stats), '/global_tokens' (global stats), '/reset_tokens' (reset session)"

    loop do
      print '> '
      user_input = gets.chomp

      case user_input
      when 'exit'
        @token_tracker.display_session_summary
        break
      when '/tokens'
        @token_tracker.display_session_summary
        next
      when '/global_tokens'
        @token_tracker.display_global_summary
        next
      when '/reset_tokens'
        @token_tracker.reset_session
        puts 'Session token counters reset.'
        next
      end

      response = @chat.ask user_input do |chunk|
        print chunk.content
      end
      puts ''

      usage_stats = @token_tracker.track_usage(response)
      @token_tracker.display_request_summary(usage_stats)
    end
  end
end
