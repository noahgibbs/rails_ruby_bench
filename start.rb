#!/usr/bin/env ruby

# Start the Rails server and measure time to first request.

# TODO: allow customizing port number

require 'rest-client'

def get_rails_server_pid
  ps_out = `ps | grep -v bin/rails | grep 4567`
  if ps_out.strip =~ /(\d+)/
    $1.to_i
  else
    nil
  end
end

def clean_server_for_startup
  server_pid = get_rails_server_pid
  if server_pid
    puts "Existing Rails server found on port 4567, killing PID #{server_pid.inspect}."
    Process.kill "KILL", server_pid
  end


end

def server_start
  # Start the server
  fork do
    system "cd work/discourse && RAILS_ENV=production rails server -p 4567"
  end
end

def server_stop
  server_pid = get_rails_server_pid
  if server_pid
    Process.kill("INT", server_pid)
    puts "Interrupted Rails server at PID #{server_pid.inspect}."
  else
    puts "No Rails server found, not killing."
  end
end

def single_run_benchmark_output_and_time
  t0 = Time.now
  loop do
    sleep 0.01
    output = `curl -f http://localhost:4567/benchmark/start 2>/dev/null`
    next unless $?.success?
    return [output, Time.now - t0]
  end
end

def with_started_server
  server_start
  yield
ensure
  server_stop
end

def with_running_server
  with_started_server do
    loop do
      sleep 0.01
      output = `curl -f http://localhost:4567/benchmark/start 2>/dev/null`
      next unless $?.success?
      yield
      return
    end
  end
end

def full_iteration_start_stop
  elapsed = nil
  with_started_server do
    server_output, elapsed = single_run_benchmark_output_and_time
    puts "Output:\n#{server_output}"
  end
  elapsed.to_f
end

def basic_iteration_get_http
  t0 = Time.now
  RestClient.get "http://localhost:4567/benchmark/simple_request"
  (Time.now - t0).to_f
end

# Run actual benchmark
clean_server_for_startup

# One Burn-in Iteration
full_iteration_start_stop

startup_times = (1..5).map { full_iteration_start_stop }
request_times = nil

with_running_server do
  request_times = (1..5).map { basic_iteration_get_http }
end

puts "===== Startup Benchmarks ====="
puts "Longest run: #{startup_times.max}"
puts "Shortest run: #{startup_times.min}"
puts "Mean: #{startup_times.inject(0.0, &:+) / startup_times.size}"
puts "Median: #{startup_times.sort[ startup_times.size / 2 ] }"
puts "Raw times: #{startup_times.inspect}"

puts "===== Startup Benchmarks ====="
puts "Longest run: #{request_times.max}"
puts "Shortest run: #{request_times.min}"
puts "Mean: #{request_times.inject(0.0, &:+) / request_times.size}"
puts "Median: #{request_times.sort[ request_times.size / 2 ] }"
puts "Raw times: #{request_times.inspect}"
