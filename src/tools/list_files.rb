# frozen_string_literal: true

require 'ruby_llm/tool'

module Tools
  # A tool for listing files and directories.
  class ListFiles < RubyLLM::Tool
    description 'Recursively list files and directories at a given path. ' \
                'If no path is provided, lists files in the current directory.'
    param :path, desc: 'Optional relative path to list files from. Defaults to current directory if not provided.'
    param :max_depth, desc: 'Maximum depth to recurse into directories'

    def execute(path: '', max_depth: 10)
      current_path = File.expand_path(path)
      return { error: 'Path does not exist' } unless Dir.exist?(current_path)

      normalized_max_depth = normalize_max_depth(max_depth)
      return { error: 'Invalid max_depth: must be a non-negative integer' } if normalized_max_depth.nil?

      results = []
      list_files_recursively(current_path, results, 0, normalized_max_depth)
      results
    rescue StandardError => e
      { error: e.message }
    end

    private

    def normalize_max_depth(max_depth)
      return max_depth if max_depth.is_a?(Integer) && max_depth >= 0
      return nil unless max_depth.is_a?(String)

      parsed = Integer(max_depth)
      parsed >= 0 ? parsed : nil
    rescue ArgumentError
      nil
    end

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
