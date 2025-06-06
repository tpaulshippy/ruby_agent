# frozen_string_literal: true

# Manages available and active tools for the agent
class ToolManager
  TOOLS = {
    'ReadFile' => Tools::ReadFile,
    'ListFiles' => Tools::ListFiles,
    'EditFile' => Tools::EditFile,
    'RunShellCommand' => Tools::RunShellCommand,
    'SavePlan' => Tools::SavePlan,
    'Empower' => ->(agent) { Tools::Empower.new(agent) },
    'Enabler' => ->(agent) { Tools::Enabler.new(agent) }
  }.freeze

  attr_reader :available_tools, :active_tools, :agent

  def initialize(agent)
    @agent = agent
    @available_tools = TOOLS.dup
    @active_tools = []
  end

  def add_tool(tool_name)
    tool_class_or_proc = @available_tools[tool_name]
    return false unless tool_class_or_proc

    unless @active_tools.include?(tool_name)
      @active_tools << tool_name
      return true
    end

    puts "⚠️  Tool #{tool_name} is already active"
    false
  end

  def remove_tool(tool_name)
    return false unless @active_tools.include?(tool_name)
    
    @active_tools.delete(tool_name)
    true
  end

  def resolve_tools
    @active_tools.map do |name|
      tool = @available_tools[name]
      tool.is_a?(Proc) ? tool.call(@agent) : tool
    end
  end

  def list_available_tools
    puts "\nAvailable Tools:"
    @available_tools.each_key do |tool_name|
      status = @active_tools.include?(tool_name) ? '✅' : '⭕'
      puts "  #{status} #{tool_name}"
    end
  end

  def self.available_tool_names
    TOOLS.keys
  end
end
