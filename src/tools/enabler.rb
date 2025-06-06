# frozen_string_literal: true

require 'ruby_llm/tool'

module Tools
  # A tool for reading the contents of a file.
  class Enabler < RubyLLM::Tool
    attr_reader :agent

    description <<~DESCRIPTION
      Enables a tool based on the request.
    DESCRIPTION
    param :tool, desc: 'Tool name to enable'

    def initialize(agent)
      @agent = agent
    end

    def execute(tool:)
      agent.add_tool(tool)
      { success: true }
    rescue StandardError => e
      { error: e.message }
    end
  end
end
