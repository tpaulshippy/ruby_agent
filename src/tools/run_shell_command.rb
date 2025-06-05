# frozen_string_literal: true

require 'ruby_llm/tool'
require 'open3'

module Tools
  class RunShellCommand < RubyLLM::Tool
    description 'Execute a linux shell command'
    param :command, desc: 'The command to execute'

    def execute(command:)
      puts '------------------Command-----------------'
      puts command
      puts '------------------------------------------'

      stdout, stderr, status = Open3.capture3(command)
      output = stdout.empty? ? stderr : stdout

      if status.success?
        puts 'Command executed successfully.'
        puts '-----------------Output-----------------'
        puts output.strip
        puts '----------------------------------------'

        { output: output.strip, success: true }
      else
        puts "Command failed with exit status #{status.exitstatus}."
        puts '-----------------Output-----------------'
        puts output.strip
        puts '----------------------------------------'
        { output: output.strip, success: false, code: status.exitstatus }
      end
    rescue StandardError => e
      { error: e.message }
    end
  end
end
