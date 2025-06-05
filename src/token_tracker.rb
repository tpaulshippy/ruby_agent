# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'time'

class TokenTracker
  GLOBAL_STATS_FILE = File.expand_path('~/.ruby_agent_token_stats.json')

  attr_reader :session_input_tokens, :session_output_tokens, :session_input_cost, :session_output_cost

  def initialize
    @session_input_tokens = 0
    @session_output_tokens = 0
    @session_input_cost = 0.0
    @session_output_cost = 0.0
    @session_started = false
    ensure_global_stats_file_exists
  end

  def track_usage(response)
    input_tokens = response.input_tokens || 0
    output_tokens = response.output_tokens || 0

    @session_input_tokens += input_tokens
    @session_output_tokens += output_tokens

    cost_info = calculate_cost(response, input_tokens, output_tokens)

    @session_input_cost += cost_info[:input_cost]
    @session_output_cost += cost_info[:output_cost]

    update_global_stats(input_tokens, output_tokens, cost_info[:input_cost], cost_info[:output_cost])

    {
      session: {
        input: @session_input_tokens,
        output: @session_output_tokens,
        total: @session_input_tokens + @session_output_tokens,
        input_cost: @session_input_cost,
        output_cost: @session_output_cost,
        total_cost: @session_input_cost + @session_output_cost
      },
      this_request: {
        input: input_tokens,
        output: output_tokens,
        total: input_tokens + output_tokens,
        input_cost: cost_info[:input_cost],
        output_cost: cost_info[:output_cost],
        total_cost: cost_info[:total_cost],
        model_id: response.model_id,
        pricing_available: cost_info[:pricing_available]
      }
    }
  end

  def session_total
    @session_input_tokens + @session_output_tokens
  end

  def session_total_cost
    @session_input_cost + @session_output_cost
  end

  def calculate_cost(response, input_tokens, output_tokens)
    model_info = RubyLLM.models.find(response.model_id)

    if model_info&.input_price_per_million && model_info.output_price_per_million
      input_cost = input_tokens * model_info.input_price_per_million / 1_000_000
      output_cost = output_tokens * model_info.output_price_per_million / 1_000_000
      total_cost = input_cost + output_cost

      {
        input_cost: input_cost,
        output_cost: output_cost,
        total_cost: total_cost,
        pricing_available: true,
        model_info: model_info
      }
    else
      {
        input_cost: 0.0,
        output_cost: 0.0,
        total_cost: 0.0,
        pricing_available: false,
        model_info: model_info
      }
    end

  rescue RubyLLM::ModelNotFoundError
    {
      input_cost: 0.0,
      output_cost: 0.0,
      total_cost: 0.0,
      pricing_available: false,
      model_info: nil
    }
  end

  def format_cost(cost)
    "$#{format('%.6f', cost)}"
  end

  def display_request_summary(usage_stats)
    if usage_stats[:this_request][:pricing_available]
      puts "\n💰 This request: #{usage_stats[:this_request][:total]} tokens " \
           "(#{usage_stats[:this_request][:input]} in, #{usage_stats[:this_request][:output]} out) | " \
           "Cost: #{format_cost(usage_stats[:this_request][:total_cost])}"
      puts "📊 Session total: #{usage_stats[:session][:total]} tokens | " \
           "Cost: #{format_cost(usage_stats[:session][:total_cost])}"
    else
      puts "\n💰 This request: #{usage_stats[:this_request][:total]} tokens " \
           "(#{usage_stats[:this_request][:input]} in, #{usage_stats[:this_request][:output]} out) | " \
           "Cost: N/A (pricing not available for #{usage_stats[:this_request][:model_id]})"
      puts "📊 Session total: #{usage_stats[:session][:total]} tokens"
    end
  end

  def global_stats
    JSON.parse(File.read(GLOBAL_STATS_FILE))
  rescue JSON::ParserError, Errno::ENOENT
    default_stats
  end

  def reset_session
    @session_input_tokens = 0
    @session_output_tokens = 0
    @session_input_cost = 0.0
    @session_output_cost = 0.0
  end

  def reset_global_stats
    File.write(GLOBAL_STATS_FILE, JSON.pretty_generate(default_stats))
  end

  def display_session_summary
    puts "\n#{'=' * 60}"
    puts 'SESSION TOKEN USAGE & COST SUMMARY'
    puts '=' * 60
    puts "Input tokens:   #{@session_input_tokens.to_s.rjust(12)}"
    puts "Output tokens:  #{@session_output_tokens.to_s.rjust(12)}"
    puts "Total tokens:   #{session_total.to_s.rjust(12)}"
    puts '-' * 60
    puts "Input cost:     #{format_cost(@session_input_cost).rjust(12)}"
    puts "Output cost:    #{format_cost(@session_output_cost).rjust(12)}"
    puts "Total cost:     #{format_cost(session_total_cost).rjust(12)}"
    puts '=' * 60
  end

  def display_global_summary
    stats = global_stats
    puts "\n#{'=' * 60}"
    puts 'GLOBAL TOKEN USAGE & COST SUMMARY'
    puts '=' * 60
    puts "Total sessions:      #{stats['total_sessions'].to_s.rjust(12)}"
    puts "Total input tokens:  #{stats['total_input_tokens'].to_s.rjust(12)}"
    puts "Total output tokens: #{stats['total_output_tokens'].to_s.rjust(12)}"
    puts "Total tokens:        #{stats['total_tokens'].to_s.rjust(12)}"
    puts '-' * 60
    puts "Total input cost:    #{format_cost(stats['total_input_cost'] || 0.0).rjust(12)}"
    puts "Total output cost:   #{format_cost(stats['total_output_cost'] || 0.0).rjust(12)}"
    puts "Total cost:          #{format_cost(stats['total_cost'] || 0.0).rjust(12)}"
    puts '-' * 60
    puts "Last updated:        #{stats['last_updated']}"
    puts '=' * 60
  end

  private

  def ensure_global_stats_file_exists
    return if File.exist?(GLOBAL_STATS_FILE)

    FileUtils.mkdir_p(File.dirname(GLOBAL_STATS_FILE))
    File.write(GLOBAL_STATS_FILE, JSON.pretty_generate(default_stats))
  end

  def default_stats
    {
      'total_sessions' => 0,
      'total_input_tokens' => 0,
      'total_output_tokens' => 0,
      'total_tokens' => 0,
      'total_input_cost' => 0.0,
      'total_output_cost' => 0.0,
      'total_cost' => 0.0,
      'first_session' => nil,
      'last_updated' => nil
    }
  end

  def update_global_stats(input_tokens, output_tokens, input_cost, output_cost)
    stats = global_stats

    if stats['first_session'].nil?
      stats['first_session'] = Time.now.iso8601
      stats['total_sessions'] = 0
    end

    unless @session_started
      stats['total_sessions'] += 1
      @session_started = true
    end

    stats['total_input_tokens'] += input_tokens
    stats['total_output_tokens'] += output_tokens
    stats['total_tokens'] = stats['total_input_tokens'] + stats['total_output_tokens']

    stats['total_input_cost'] = (stats['total_input_cost'] || 0.0) + input_cost
    stats['total_output_cost'] = (stats['total_output_cost'] || 0.0) + output_cost
    stats['total_cost'] = stats['total_input_cost'] + stats['total_output_cost']

    stats['last_updated'] = Time.now.iso8601

    File.write(GLOBAL_STATS_FILE, JSON.pretty_generate(stats))
  rescue StandardError => e
    puts "Warning: Could not update global token stats: #{e.message}"
  end
end
