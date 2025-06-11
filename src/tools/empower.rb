# frozen_string_literal: true

require 'ruby_llm/tool'

module Tools
  class Empower < RubyLLM::Tool
    description <<~DESCRIPTION
      Evaluate Ruby code to define a new tool class and add it to the chat.
      The code should define a class that inherits from RubyLLM::Tool.

      The code should be in the following format:
      ```ruby
      class MyNewTool < RubyLLM::Tool
        description 'Description of the tool'
        param :param_name, desc: 'Description of the parameter'

        def execute(param_name:)
          # Implementation of the tool
        rescue StandardError => e
          { error: e.message }
        end
      end
      ```

    DESCRIPTION
    param :code, desc: 'Ruby code that defines a tool class inheriting from RubyLLM::Tool'
    param :tool_name, desc: 'Name of the tool class to add (e.g., "MyNewTool")'

    def initialize(agent)
      super()
      @agent = agent
    end

    def execute(code:, tool_name:)
      evaluate_and_add_tool(code, tool_name)
    end

    private

    def evaluate_and_add_tool(code, tool_name)
      log_evaluation(code)

      puts 'Do you want to proceed with adding this tool? (y/n)'
      return unless gets.chomp == 'y'

      # First validate the syntax
      syntax_ok, error = validate_ruby_syntax(code)
      return { error: "Invalid Ruby syntax: #{error}" } unless syntax_ok

      # If syntax is valid, proceed with evaluation
      begin
        eval(code, TOPLEVEL_BINDING)
        tool_class = find_tool_class(tool_name)
        handle_evaluation_result(tool_class, tool_name)
      rescue StandardError => e
        { error: "Failed to evaluate tool code: #{e.message}" }
      end
    end

    def validate_ruby_syntax(code)
      # Create a RubyVM::InstructionSequence to check syntax
      RubyVM::InstructionSequence.compile(code)
      [true, nil]
    rescue SyntaxError => e
      # Extract just the error message without the code snippet
      error_message = e.message.lines.first.chomp
      [false, error_message]
    end

    def log_evaluation(code)
      puts '----------------Empowering Tool Code----------------'
      puts code
      puts '---------------------------------------------------'
    end

    def handle_evaluation_result(tool_class, tool_name)
      return { error: "Tool class #{tool_name} not found after evaluation" } if tool_class.nil?
      return { error: "#{tool_name} does not inherit from RubyLLM::Tool" } unless tool_class < RubyLLM::Tool

      if tool_already_active?(tool_class)
        puts "⚠️  Tool #{tool_name} is already active"
        { success: false, message: "Tool #{tool_name} is already active" }
      else
        add_tool_to_agent(tool_class, tool_name)
      end
    end

    def find_tool_class(tool_name)
      lookup_methods = [
        -> { Object.const_get(tool_name) },
        -> { const_get(tool_name) },
        -> { Object.const_get("::#{tool_name}") },
        -> { Kernel.const_get(tool_name) }
      ]

      lookup_methods.each do |lookup|
        return lookup.call
      rescue NameError
        next
      end
      nil
    end

    def tool_already_active?(tool_class)
      @agent.active_tools.any? { |t| t.is_a?(Class) ? t == tool_class : t.instance_of?(tool_class) }
    end

    def add_tool_to_agent(tool_class, tool_name)
      @agent.active_tools << tool_name
      @agent.available_tools[tool_name] = tool_class
      @agent.enable_tools
      puts "✅ Successfully evaluated and added tool: #{tool_name}"
      { success: true, message: "Tool #{tool_name} has been evaluated and added to the chat" }
    end
  end
end
