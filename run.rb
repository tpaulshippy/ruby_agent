#!/usr/bin/env ruby

# Load the gems and environment variables from .env file.
Dir.chdir(__dir__) do
  require "bundler/setup"
  require "dotenv/load"
end

require "ruby_llm"
require "ruby_llm/mcp"
require_relative "src/agent"
require_relative "aws"

RubyLLM.configure do |config|
  config.ollama_api_base = ENV.fetch("OLLAMA_API_BASE", "http://localhost:11434/v1")
  configure_ruby_llm_aws(config)
end

Agent.new.run
