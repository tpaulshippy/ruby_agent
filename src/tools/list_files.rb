# frozen_string_literal: true

require 'ruby_llm/tool'

module Tools
  class ListFiles < RubyLLM::Tool
    description 'Recursively list files and directories at a given path. If no path is provided, lists files in the current directory.'
    param :path, desc: 'Optional relative path to list files from. Defaults to current directory if not provided.'
    param :recursive, desc: 'If true, recursively list all files and subdirectories'
    param :max_depth, desc: 'Maximum depth to recurse into directories'

    def execute(path: '', recursive: false, max_depth: 10)
      current_path = File.expand_path(path)
      return { error: 'Path does not exist' } unless Dir.exist?(current_path)

      results = []
      list_files_recursively(current_path, results, 0, max_depth)
      results
    rescue StandardError => e
      { error: e.message }
    end

    private

    def list_files_recursively(path, results, current_depth, max_depth)
      Dir.glob(File.join(path, '*')).each do |filename|
        if File.directory?(filename)
          results << "#{filename}/"
          list_files_recursively(filename, results, current_depth + 1, max_depth) if current_depth < max_depth
        else
          results << filename
        end
      end
    end
  end
end
