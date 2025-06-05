# frozen_string_literal: true

require 'ruby_llm/tool'

module Tools
  # A tool for editing files.
  class EditFile < RubyLLM::Tool
    description <<~DESCRIPTION
      Make edits to a text file.

      Replaces 'old_str' with 'new_str' in the given file.
      'old_str' and 'new_str' MUST be different from each other.

      If the file specified with path doesn't exist, it will be created.
    DESCRIPTION
    param :path, desc: 'The path to the file'
    param :old_str, desc: 'Text to search for - must match exactly and must only have one match exactly'
    param :new_str, desc: 'Text to replace old_str with'

    def execute(path:, old_str:, new_str:)
      puts "Editing file: #{path}"
      content = File.exist?(path) ? File.read(path) : ''
      File.write(path, content.sub(old_str, new_str))
    rescue StandardError => e
      { error: e.message }
    end
  end
end
