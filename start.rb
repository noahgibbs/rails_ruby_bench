#!/usr/bin/env ruby

# Start the Rails server and measure time to first request.

# TODO: allow customizing port number

def get_rails_server_pid
  ps_out = `ps | grep -v grep | grep puma | grep MarkApp | grep 4567`
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
    system "cd MarkApp && RAILS_ENV=production rails server -p 4567"
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

def with_running_server
  server_start
  yield
ensure
  server_stop
end

def full_iteration_start_stop
  elapsed = nil
  with_running_server do
    server_output, elapsed = single_run_benchmark_output_and_time
    puts "Output:\n#{server_output}"
  end
  elapsed.to_f
end

# Run actual benchmark
clean_server_for_startup

# Burn-in
full_iteration_start_stop

iter_times = (1..5).map { full_iteration_start_stop }

puts "Longest run: #{iter_times.max}"
puts "Shortest run: #{iter_times.min}"
puts "Mean: #{iter_times.inject(0.0, &:+) / iter_times.size}"
puts "Median: #{iter_times.sort[ iter_times.size / 2 ] }"
