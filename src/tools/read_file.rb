# frozen_string_literal: true

require 'ruby_llm/tool'

module Tools
  class ReadFile < RubyLLM::Tool
    description "Read the contents of a given relative file path. Use this when you want to see what's inside a file. Do not use this with directory names."
    param :path, desc: 'The relative path of a file in the working directory.'

    def execute(path:)
      File.read(path)
    rescue StandardError => e
      { error: e.message }
    end
  end
end
