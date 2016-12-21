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
    print "Existing Rails server found on port 4567, killing PID #{server_pid.inspect}.\n"
    Process.kill "KILL", server_pid
  end
end

def server_start
  # Start the server
  fork do
    STDERR.print "In PID #{Process.pid}, starting server on port 4567\n"
    system "cd work/discourse && RAILS_ENV=profile rails server -p 4567"
  end
end

# TODO: Proper audit on this code. Right now it assumes no child processes means no Rails server running, which isn't quite right.

def server_stop
  server_pid = get_rails_server_pid
  if server_pid
    Process.kill("INT", server_pid)
    print "server_stop: Interrupted Rails server at PID #{server_pid.inspect}.\n"
    loop do
      # Verify that server we started is sufficiently dead before we restart
      STDERR.print "Waiting for dead PID\n"
      dead_pid = Process.waitpid
      STDERR.print "Got dead pid: #{dead_pid.inspect}\n"
      break if dead_pid == server_pid
    end
  else
    print "No Rails server found, not killing.\n"
  end
rescue Errno::ECHILD
  # Found no child processes... Which means that whatever we're attempting to wait for, it's already dead.
  print "No child processes, moving on with our day.\n"
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
      print "Trying iter #{failed_iters}...\n"
      output = `curl -f http://localhost:4567/ 2>/dev/null`
      if $?.success?
        yield
        return
      else
        failed_iters += 1
      end
      print "Failed #{failed_iters} iterations and counting...\n"
    end
  end
end

def full_iteration_start_stop
  elapsed = nil
  with_started_server do
    print "Server is started, running start/stop iteration...\n"
    server_output, elapsed = single_run_benchmark_output_and_time
    #print "Output:\n#{server_output}\n"
  end
  elapsed.to_f
end

def basic_iteration_get_http
  t0 = Time.now
  RestClient.get "http://localhost:4567/benchmark/simple_request"
  (Time.now - t0).to_f
end

print "Checking for previous running Rails server...\n"
clean_server_for_startup

# One Burn-in Iteration
print "Starting and stopping server to preload caches...\n"
full_iteration_start_stop

print "Running start-time benchmarks for #{STARTUP_ITERATIONS} iterations...\n"
startup_times = (1..STARTUP_ITERATIONS).map { full_iteration_start_stop }
request_times = nil

# TODO: fork workers *before* starting timer, then send data over a pipe to each of them to begin.

children = {}

# TODO: actually check user IDs in database. Right now, I assume we're dropping-and-recreating with the DB seed script.

(1..NUMBER_OF_WORKERS).map do |worker_num|
  pid = fork do
    cmd = "/usr/bin/env ruby ./user_simulator.rb -o #{worker_num - 1} -r #{INITIAL_RAND_SEED + 100 * worker_num} -n #{WORKER_ITERATIONS} -w 0 -d 0"
    print "PID #{Process.pid} RUNNING: #{cmd}\n"
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
if children.values.all? { |c| c[:elapsed] && c[:status].success? }
  # All children finished successfully, get elapsed times
  worker_times = children.values.map { |v| v[:elapsed] }
elsif children.values.all? { |c| c[:elapsed] }
  # All children finished, at least one failed
  STDERR.print "********* At least one worker process failed! No benchmark data collected. *********\n"
  exit -1
else
  STDERR.print "********* Not all child processes exited! You may need to clean up! **********\n"
  exit -1
end

print "===== Startup Benchmarks =====\n"
print "Longest run: #{startup_times.max}\n"
print "Shortest run: #{startup_times.min}\n"
print "Mean: #{startup_times.inject(0.0, &:+) / startup_times.size}\n"
print "Median: #{startup_times.sort[ startup_times.size / 2 ] }\n"
print "Raw times: #{startup_times.inspect}\n"

print "===== Startup Benchmarks =====\n"
print "Longest run: #{worker_times.max}\n"
print "Shortest run: #{worker_times.min}\n"
print "Mean: #{worker_times.inject(0.0, &:+) / worker_times.size}\n"
print "Median: #{worker_times.sort[ worker_times.size / 2 ] }\n"
print "Raw times: #{worker_times.inspect}\n"
