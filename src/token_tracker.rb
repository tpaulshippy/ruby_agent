require "json"
require "fileutils"
require "time"

class TokenTracker
  GLOBAL_STATS_FILE = File.expand_path("~/.ruby_agent_token_stats.json")
  
  attr_reader :session_input_tokens, :session_output_tokens
  
  def initialize
    @session_input_tokens = 0
    @session_output_tokens = 0
    @session_started = false
    ensure_global_stats_file_exists
  end
  
  def track_usage(response)
    input_tokens = response.input_tokens || 0
    output_tokens = response.output_tokens || 0
    
    @session_input_tokens += input_tokens
    @session_output_tokens += output_tokens
    
    update_global_stats(input_tokens, output_tokens)
    
    {
      session: {
        input: @session_input_tokens,
        output: @session_output_tokens,
        total: @session_input_tokens + @session_output_tokens
      },
      this_request: {
        input: input_tokens,
        output: output_tokens,
        total: input_tokens + output_tokens
      }
    }
  end
  
  def session_total
    @session_input_tokens + @session_output_tokens
  end
  
  def global_stats
    JSON.parse(File.read(GLOBAL_STATS_FILE))
  rescue JSON::ParserError, Errno::ENOENT
    default_stats
  end
  
  def reset_session
    @session_input_tokens = 0
    @session_output_tokens = 0
  end
  
  def reset_global_stats
    File.write(GLOBAL_STATS_FILE, JSON.pretty_generate(default_stats))
  end
  
  def display_session_summary
    puts "\n" + "=" * 50
    puts "SESSION TOKEN USAGE SUMMARY"
    puts "=" * 50
    puts "Input tokens:  #{@session_input_tokens.to_s.rjust(10)}"
    puts "Output tokens: #{@session_output_tokens.to_s.rjust(10)}"
    puts "Total tokens:  #{session_total.to_s.rjust(10)}"
    puts "=" * 50
  end
  
  def display_global_summary
    stats = global_stats
    puts "\n" + "=" * 50
    puts "GLOBAL TOKEN USAGE SUMMARY"
    puts "=" * 50
    puts "Total sessions:     #{stats['total_sessions'].to_s.rjust(10)}"
    puts "Total input tokens: #{stats['total_input_tokens'].to_s.rjust(10)}"
    puts "Total output tokens:#{stats['total_output_tokens'].to_s.rjust(10)}"
    puts "Total tokens:       #{stats['total_tokens'].to_s.rjust(10)}"
    puts "Last updated:       #{stats['last_updated']}"
    puts "=" * 50
  end
  
  private
  
  def ensure_global_stats_file_exists
    return if File.exist?(GLOBAL_STATS_FILE)
    
    FileUtils.mkdir_p(File.dirname(GLOBAL_STATS_FILE))
    File.write(GLOBAL_STATS_FILE, JSON.pretty_generate(default_stats))
  end
  
  def default_stats
    {
      "total_sessions" => 0,
      "total_input_tokens" => 0,
      "total_output_tokens" => 0,
      "total_tokens" => 0,
      "first_session" => nil,
      "last_updated" => nil
    }
  end
  
  def update_global_stats(input_tokens, output_tokens)
    stats = global_stats
    
    if stats["first_session"].nil?
      stats["first_session"] = Time.now.iso8601
      stats["total_sessions"] = 0
    end
    
    unless @session_started
      stats["total_sessions"] += 1
      @session_started = true
    end
    
    stats["total_input_tokens"] += input_tokens
    stats["total_output_tokens"] += output_tokens
    stats["total_tokens"] = stats["total_input_tokens"] + stats["total_output_tokens"]
    stats["last_updated"] = Time.now.iso8601
    
    File.write(GLOBAL_STATS_FILE, JSON.pretty_generate(stats))
  rescue => e
    puts "Warning: Could not update global token stats: #{e.message}"
  end
end
