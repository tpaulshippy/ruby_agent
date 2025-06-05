# frozen_string_literal: true

require 'ruby_llm'
require 'ruby_llm/mcp'
require_relative 'tools/write_plan'
require_relative 'tools/read_file'
require_relative 'tools/list_files'
require_relative 'tools/edit_file'
require_relative 'tools/run_shell_command'
require_relative 'mcp/client'
require_relative 'token_tracker'

class Agent
  attr_reader :chat, :token_tracker

  def initialize
    @token_tracker = TokenTracker.new
    model_id = ENV.fetch('MODEL_ID', 'qwen3:14b')
    provider = ENV.fetch('PROVIDER', 'ollama')
    @chat = RubyLLM.chat(model: model_id, provider: provider, assume_model_exists: provider == 'ollama')

    if ARGV.delete('--planner')
      chat.with_instructions File.read('prompts/planner.txt')

      files = Tools::ListFiles.new.execute(path: '', recursive: true)
      raise files[:error] if files.is_a?(Hash) && files.key?(:error)
      chat.with_instructions "Found files:\n#{files.join('\n')}"

      tools = [
        Tools::WritePlan,
        Tools::ReadFile,
        Tools::ListFiles,
      ]
    else
      chat.with_instructions File.read("prompts/#{model_id}.txt")
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
    end

    chat.with_tools(*tools)
  end

  def setup_event_handlers
    chat.on_new_message do
      puts "Assistant is typing..."
    end
    chat.on_end_message do |message|
      return unless message

      if message.tool_call?
        tool_names = []
        message.tool_calls.each_value do |tool_call|
          tool_names << tool_call.name
        end
        puts "Calling tools: #{tool_names.join(', ')}"
      else
        puts ""
        puts "Response complete!"
      end

      if message.output_tokens
        usage_stats = token_tracker.track_usage(message)
        token_tracker.display_request_summary(usage_stats)
      end
    end
  end

  def run
    puts "Chat with the agent. Type 'exit' to ... well, exit"
    puts "Special commands: '/tokens' (session stats), '/global_tokens' (global stats), '/reset_tokens' (reset session)"

    setup_event_handlers

    loop do
      print '> '
      user_input = gets.chomp

      case user_input
      when 'exit'
        token_tracker.display_session_summary
        break
      when '/tokens'
        token_tracker.display_session_summary
        next
      when '/global_tokens'
        token_tracker.display_global_summary
        next
      when '/reset_tokens'
        token_tracker.reset_session
        puts 'Session token counters reset.'
        next
      end

      chat.ask user_input do |chunk|
        print chunk.content
      end
    end
  end
end
