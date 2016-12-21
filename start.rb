#!/usr/bin/env ruby

# Start the Rails server and measure time to first request.

# TODO: add command-line options, including:
#
# * port number of Rails server
# * number of worker processes
# * iterations per worker
# * random seed
# * startup iterations (to measure startup time)
# * warmup iterations (before measuring requests)

require 'rest-client'

STARTUP_ITERATIONS = 2
NUMBER_OF_WORKERS = 5
INITIAL_RAND_SEED = 16541799507913229037  # Chosen via irb and '(1..20).map { (0..9).to_a.sample }.join("")'

# This is an interesting question. A larger number means more chance for the randomized trials to even out.
# A smaller number means the benchmark completes more quickly.
WORKER_ITERATIONS = 300

def get_rails_server_pid
  ps_out = `ps | grep -v grep | grep bin/rails | grep 4567`
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
    STDERR.puts "In PID #{Process.pid}, starting server on port 4567"
    system "cd work/discourse && RAILS_ENV=profile rails server -p 4567"
  end
end

# TODO: Proper audit on this code. Right now it assumes no child processes means no Rails server running, which isn't quite right.

def server_stop
  server_pid = get_rails_server_pid
  if server_pid
    Process.kill("INT", server_pid)
    puts "server_stop: Interrupted Rails server at PID #{server_pid.inspect}."
    loop do
      # Verify that server we started is sufficiently dead before we restart
      STDERR.puts "Waiting for dead PID"
      dead_pid = Process.waitpid
      STDERR.puts "Got dead pid: #{dead_pid.inspect}"
      break if dead_pid == server_pid
    end
  else
    puts "No Rails server found, not killing."
  end
rescue Errno::ECHILD
  # Found no child processes... Which means that whatever we're attempting to wait for, it's already dead.
  puts "No child processes, moving on with our day."
end

def single_run_benchmark_output_and_time
  t0 = Time.now
  loop do
    sleep 0.01
    output = `curl -f http://localhost:4567/ 2>/dev/null`
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
    failed_iters = 0
    loop do
      sleep 0.01
      puts "Trying iter #{failed_iters}..."
      output = `curl -f http://localhost:4567/ 2>/dev/null`
      if $?.success?
        yield
        return
      else
        failed_iters += 1
      end
      puts "Failed #{failed_iters} iterations and counting..."
    end
  end
end

def full_iteration_start_stop
  elapsed = nil
  with_started_server do
    puts "Server is started, running start/stop iteration..."
    server_output, elapsed = single_run_benchmark_output_and_time
    #puts "Output:\n#{server_output}"
  end
  elapsed.to_f
end

def basic_iteration_get_http
  t0 = Time.now
  RestClient.get "http://localhost:4567/benchmark/simple_request"
  (Time.now - t0).to_f
end

puts "Checking for previous running Rails server..."
clean_server_for_startup

# One Burn-in Iteration
puts "Starting and stopping server to preload caches..."
full_iteration_start_stop

puts "Running start-time benchmarks for #{STARTUP_ITERATIONS} iterations..."
startup_times = (1..STARTUP_ITERATIONS).map { full_iteration_start_stop }
request_times = nil

# TODO: fork workers *before* starting timer, then send data over a pipe to each of them to begin.

children = {}

# TODO: actually check user IDs in database. Right now, I assume we're dropping-and-recreating with the DB seed script.

(1..NUMBER_OF_WORKERS).map do |worker_num|
  pid = fork do
    cmd = "/usr/bin/env ruby ./user_simulator.rb -u #{worker_num + 5} -r #{INITIAL_RAND_SEED + 100 * worker_num} -n #{WORKER_ITERATIONS} -w 0 -d 0"
    puts "PID #{Process.pid} RUNNING: #{cmd}"
    exec cmd
    raise "Should never get here! Exec failed!"
    exit!(-1)
  end

  # Save start time of each worker process
  children[pid] = {
    :start_time => Time.now,
    :elapsed => nil
  }
end

# These aren't perfect elapsed times, for several reasons.
# TODO: measure elapsed time in the child process,
# pass it back to the parent, like in ABProf.
while children.values.any? { |c| c[:elapsed].nil? }
  finished_pid = Process.waitpid
  children[finished_pid][:elapsed] = Time.now - children[finished_pid][:start_time]

  # Save status object
  children[finished_pid][:status] = $?
end

worker_times = []
if children.all? { |c| c[:elapsed] && c[:status].success? }
  # All children finished successfully, get elapsed times
  worker_times = children.values.map { |v| v[:elapsed] }
elsif children.all? { |c| c[:elapsed] }
  # All children finished, at least one failed
  STDERR.puts "********* At least one worker process failed! No benchmark data collected. *********"
  exit -1
else
  STDERR.puts "********* Not all child processes exited! You may need to clean up! **********"
  exit -1
end

puts "===== Startup Benchmarks ====="
puts "Longest run: #{startup_times.max}"
puts "Shortest run: #{startup_times.min}"
puts "Mean: #{startup_times.inject(0.0, &:+) / startup_times.size}"
puts "Median: #{startup_times.sort[ startup_times.size / 2 ] }"
puts "Raw times: #{startup_times.inspect}"

puts "===== Startup Benchmarks ====="
puts "Longest run: #{worker_times.max}"
puts "Shortest run: #{worker_times.min}"
puts "Mean: #{worker_times.inject(0.0, &:+) / worker_times.size}"
puts "Median: #{worker_times.sort[ worker_times.size / 2 ] }"
puts "Raw times: #{worker_times.inspect}"
