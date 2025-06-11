# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'ruby_llm'
require 'ruby_llm/mcp'
require_relative 'tools/save_plan'
require_relative 'tools/read_file'
require_relative 'tools/list_files'
require_relative 'tools/edit_file'
require_relative 'tools/run_shell_command'
require_relative 'tools/empower'
require_relative 'tools/enabler'
require_relative 'tool_manager'
require_relative 'mcp/client'
require_relative 'token_tracker'

# A class representing an agent.
class Agent
  attr_reader :chat, :token_tracker, :tool_manager, :system_prompt

  def initialize
    @token_tracker = TokenTracker.new
    @plan = nil
    @tool_manager = ToolManager.new(self)

    # Handle --plan argument
    if (plan_arg = ARGV.find { |arg| arg.start_with?('--plan=') }&.split('=')&.last)
      ARGV.delete_if { |arg| arg.start_with?('--plan=') }
      plan_path = plan_arg.include?('/') ? plan_arg : File.join('plans', "#{plan_arg}.md")
      @plan = load_plan(plan_path)
      exit(1) if @plan.empty?
    end

    if ARGV.delete('--planner')
      @system_prompt += "\n\n#{File.read('prompts/planner.txt')}"
      %w[SavePlan ReadFile ListFiles].each { |tool| add_tool(tool) }
    else
      # mcp_client = MCP::Client.from_json_file || MCP::Client.from_env
      # if mcp_client
      # puts 'MCP client connected. Adding MCP tools...'
      # mcp_client.tools.each { |tool| @tool_manager.add_tool(tool) }
      # end
    end

    setup_chat
    add_tool('Enabler')
  end

  # Delegate tool management methods to the ToolManager
  def add_tool(tool_name)
    if @tool_manager.add_tool(tool_name)
      enable_tools
      @tool_manager.list_available_tools
      true
    else
      false
    end
  end

  def enable_tools
    chat.with_tools(*@tool_manager.resolve_tools)
  end

  def remove_tools
    @tool_manager.remove_tools
    chat.clear_tools
  end

  def list_available_tools
    @tool_manager.list_available_tools
  end

  def active_tools
    @tool_manager.active_tools
  end

  def available_tools
    @tool_manager.available_tools
  end

  def url?(string)
    uri = URI.parse(string)
    uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end

  def download_prompt(url)
    uri = URI.parse(url)
    response = Net::HTTP.get_response(uri)
    if response.is_a?(Net::HTTPSuccess)
      response.body
    else
      puts "Warning: Could not download prompt from URL: #{url} (HTTP #{response.code})"
      url
    end
  rescue StandardError => e
    puts "Warning: Could not download prompt from URL: #{url} (#{e.message})"
    url
  end

  def setup_event_handlers
    chat.on_new_message do
      # puts 'Assistant is typing...'
    end
    chat.on_end_message do |message|
      return unless message

      if message.output_tokens
        usage_stats = token_tracker.track_usage(message)
        token_tracker.display_request_summary(usage_stats)
      end
    end
  end

  def load_plan(plan_path)
    if File.exist?(plan_path)
      @plan = File.read(plan_path)
      puts "Loaded plan with #{@plan.size} characters"
      @plan
    else
      puts "Plan not found: #{plan_path}"
      ''
    end
  end

  def reset_chat
    setup_chat
    enable_tools
    puts "Chat has been reset with the system message and #{active_tools.size} active tools."
  end

  def run
    puts "Chat with the agent. Type 'exit' to ... well, exit"
    puts 'Special commands:'
    puts '  /tokens - Show session token usage'
    puts '  /global_tokens - Show global token usage'
    puts '  /reset_tokens - Reset session token counters'
    puts '  /reset - Reinitialize the chat with system message and tools'
    puts '  /plan <name> - Execute a plan from the plans/ directory (or use --plan=name)'
    puts '  /tool:<ToolName> - Add a tool dynamically (e.g., /tool:ReadFile)'
    puts '  /tools - List available and active tools'
    puts '  /reset_tools - Remove all active tools'

    loop do
      if @plan
        user_input = @plan
        @plan = nil
      else
        print '> '
        user_input = gets.chomp
      end

      case user_input
      when 'exit'
        token_tracker.display_session_summary
        break
      when '/reset'
        reset_chat
        next
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
      when '/tools'
        list_available_tools
        next
      when '/reset_tools'
        remove_tools
        puts 'All tools removed.'
        next
      when %r{^/tool:(.+)}
        tool_name = ::Regexp.last_match(1).strip
        if add_tool(tool_name)
          puts "✅ Enabled tool: #{tool_name}"
        else
          puts "⚠️  Unknown tool: #{tool_name}"
        end
        next
      when %r{^/plan\s+(.+)}
        plan_name = ::Regexp.last_match(1).strip
        plan_path = plan_name.include?('/') ? plan_name : File.join('plans', "#{plan_name}.md")
        load_plan(plan_path)
        next
      end

      chat.ask user_input do |chunk|
        print chunk.content
      end
    end
  end

  private

  def setup_chat
    model_id = ENV.fetch('MODEL_ID', 'qwen3:14b')
    @system_prompt = File.read("prompts/#{model_id}.txt")

    @chat = RubyLLM.chat(
      model: model_id,
      provider: ENV.fetch('PROVIDER', 'ollama'),
      assume_model_exists: ENV.fetch('PROVIDER', 'ollama') == 'ollama'
    )

    chat.with_instructions(system_prompt)
    setup_event_handlers
  end
end
