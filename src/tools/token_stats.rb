require "ruby_llm/tool"

module Tools
  class TokenStats < RubyLLM::Tool
    description "View or manage token usage statistics for this agent session and globally"
    param :action, desc: "Action to perform: 'session' (show session stats), 'global' (show global stats), 'reset_session' (reset session counters), or 'reset_global' (reset all global stats)"

    def initialize(token_tracker)
      @token_tracker = token_tracker
    end

    def execute(action:)
      case action.downcase
      when "session"
        stats = {
          session_input_tokens: @token_tracker.session_input_tokens,
          session_output_tokens: @token_tracker.session_output_tokens,
          session_total_tokens: @token_tracker.session_total
        }
        "Current session token usage: #{stats[:session_input_tokens]} input + #{stats[:session_output_tokens]} output = #{stats[:session_total_tokens]} total tokens"
      when "global"
        stats = @token_tracker.global_stats
        "Global token usage across all sessions: #{stats['total_input_tokens']} input + #{stats['total_output_tokens']} output = #{stats['total_tokens']} total tokens across #{stats['total_sessions']} sessions. Last updated: #{stats['last_updated']}"
      when "reset_session"
        @token_tracker.reset_session
        "Session token counters have been reset to zero."
      when "reset_global"
        @token_tracker.reset_global_stats
        "Global token statistics have been reset to zero."
      else
        { error: "Invalid action. Use 'session', 'global', 'reset_session', or 'reset_global'" }
      end
    rescue => e
      { error: e.message }
    end
  end
end 
