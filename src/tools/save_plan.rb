# frozen_string_literal: true

require 'ruby_llm/tool'

module Tools
  # A tool for saving plans.
  class SavePlan < RubyLLM::Tool
    description 'Save the plan to a markdown file'
    param :content, desc: 'Detailed plan in markdown'
    param :title, desc: 'Title of the plan'

    def execute(content:, title:)
      puts "Saving plan to plans/#{title}.md"
      File.write("plans/#{title}.md", content)
      { success: true, filename: "plans/#{title}.md" }
    rescue StandardError => e
      { error: e.message }
    end
  end
end
