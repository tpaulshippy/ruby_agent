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
require_relative 'mcp/client'
require_relative 'token_tracker'

# A class representing an agent.
class Agent
  attr_reader :chat, :token_tracker, :active_tools, :available_tools, :system_prompt

  def initialize
    @token_tracker = TokenTracker.new
    @plan = nil
    @active_tools = []
    @available_tools = build_tool_mapping
    
    # Handle --plan argument
    if (plan_arg = ARGV.find { |arg| arg.start_with?('--plan=') }&.split('=')&.last)
      ARGV.delete_if { |arg| arg.start_with?('--plan=') }
      plan_path = plan_arg.include?('/') ? plan_arg : File.join('plans', "#{plan_arg}.md")
      @plan = load_plan(plan_path)
      exit(1) if @plan.empty?
    end

    if ARGV.delete('--planner')
      @system_prompt += "\n\n#{File.read('prompts/planner.txt')}"
      @active_tools = ['SavePlan', 'ReadFile', 'ListFiles']
    else
      mcp_client = MCP::Client.from_json_file || MCP::Client.from_env
      if mcp_client
        # puts 'MCP client connected. Adding MCP tools...'
        # tools.concat(mcp_client.tools)
      end
    end

    setup_chat
  end

  private

  def build_tool_mapping
    {
      'ReadFile' => Tools::ReadFile,
      'ListFiles' => Tools::ListFiles,
      'EditFile' => Tools::EditFile,
      'RunShellCommand' => Tools::RunShellCommand,
      'SavePlan' => Tools::SavePlan,
      'Empower' => -> { Tools::Empower.new(self) }
    }
  end

  def add_tool(tool_name)
    tool_class_or_proc = @available_tools[tool_name]
    return false unless tool_class_or_proc

    unless @active_tools.include?(tool_name)
      @active_tools << tool_name
      chat.with_tools(*resolve_tools)
      list_available_tools
      return true
    end

    puts "⚠️  Tool #{tool_name} is already active"
    false
  end

  private

  def resolve_tools
    @active_tools.map do |name|
      tool = @available_tools[name]
      tool.is_a?(Proc) ? tool.call : tool
    end
  end

  def list_available_tools
    puts "\nTools:"
    @available_tools.each_key do |tool_name|
      status = @active_tools.include?(tool_name) ? '✅' : '⭕'
      puts "  #{status} #{tool_name}"
    end
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

  public

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
    puts "Chat has been reset with the system message and #{@active_tools.size} active tools."
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
      when %r{^/tool:(.+)}
        tool_name = ::Regexp.last_match(1).strip
        add_tool(tool_name)
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

    chat.with_tools(*resolve_tools) if @active_tools&.any?
    chat.with_instructions(system_prompt)
    setup_event_handlers
  end

end
