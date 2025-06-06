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
  attr_reader :chat, :token_tracker, :active_tools

  def initialize
    @token_tracker = TokenTracker.new
    model_id = ENV.fetch('MODEL_ID', 'qwen3:14b')
    provider = ENV.fetch('PROVIDER', 'ollama')
    @chat = RubyLLM.chat(model: model_id, provider: provider, assume_model_exists: provider == 'ollama')
    system_prompt = File.read("prompts/#{model_id}.txt")

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
      system_prompt += "\n\n#{File.read('prompts/planner.txt')}"

      @active_tools = [Tools::SavePlan, Tools::ReadFile, Tools::ListFiles]
      chat.with_tools(*@active_tools)
    else
      mcp_client = MCP::Client.from_json_file || MCP::Client.from_env
      if mcp_client
        # puts 'MCP client connected. Adding MCP tools...'
        # tools.concat(mcp_client.tools)
      end
    end

    chat.with_instructions(system_prompt)
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

    tool_class = tool_class_or_proc.is_a?(Proc) ? tool_class_or_proc.call.class : tool_class_or_proc
    tool_instance = tool_class_or_proc.is_a?(Proc) ? tool_class_or_proc.call : nil

    unless @active_tools.include?(tool_class) || (tool_instance && @active_tools.any? do |t|
      t.instance_of?(tool_class)
    end)
      @active_tools << (tool_instance || tool_class)
      chat.with_tools(*@active_tools)
      puts "✅ Added tool: #{tool_name}"
      return true
    end

    puts "⚠️  Tool #{tool_name} is already active"
    false
  end

  def list_available_tools
    puts "\nTools:"
    @available_tools.each_key do |tool_name|
      status = @active_tools.any? { |tool| tool.name.split('::').last == tool_name } ? '✅' : '⭕'
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
      puts 'Assistant is typing...'
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

  def run
    puts "Chat with the agent. Type 'exit' to ... well, exit"
    puts 'Special commands:'
    puts '  /tokens - Show session token usage'
    puts '  /global_tokens - Show global token usage'
    puts '  /reset_tokens - Reset session token counters'
    puts '  /plan <name> - Execute a plan from the plans/ directory (or use --plan=name)'
    puts '  /tool:<ToolName> - Add a tool dynamically (e.g., /tool:ReadFile)'
    puts '  /tools - List available and active tools'

    setup_event_handlers

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
end
