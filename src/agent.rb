require "ruby_llm"
require "ruby_llm/mcp"
require_relative "tools/read_file"
require_relative "tools/list_files"
require_relative "tools/edit_file"
require_relative "tools/run_shell_command"
require_relative "mcp/client"

class Agent
  def initialize
    @chat = RubyLLM.chat(model: "qwen3:14b", provider: :ollama, assume_model_exists: true)
    @chat.with_instructions <<~INSTRUCTIONS
      Perform the tasks requested as quickly as possible.
      /no_think
    INSTRUCTIONS
    
    tools = [Tools::ReadFile, Tools::ListFiles, Tools::EditFile, Tools::RunShellCommand]
    
    mcp_client = MCP::Client.from_json_file || MCP::Client.from_env
    if mcp_client
      puts "MCP client connected. Adding MCP tools..."
      tools.concat(mcp_client.tools)
    end
    
    @chat.with_tools(*tools)
  end

  def run
    puts "Chat with the agent. Type 'exit' to ... well, exit"
    loop do
      print "> "
      user_input = gets.chomp
      break if user_input == "exit"

      response = @chat.ask user_input do |chunk|
        print chunk.content
      end
      puts ""
    end
  end
end
