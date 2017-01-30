#!/usr/bin/env ruby

# Start the Rails server and measure time to first request.

# TODO: add command-line options for:
#
# * port number of Rails server

require 'optparse'
require 'rest-client'

# Run this in "profile" environment for Discourse.
ENV['RAILS_ENV'] = 'profile'

startup_iters = 2
random_seed = 16541799507913229037  # Chosen via irb and '(1..20).map { (0..9).to_a.sample }.join("")'
worker_iterations = 300
warmup_iterations = 0
workers = 5
port_num = 4567

OptionParser.new do |opts|
  opts.banner = "Usage: ruby start.rb [options]"
  opts.on("-r", "--random-seed NUMBER", "random seed") do |r|
    random_seed = r.to_i
  end
  opts.on("-i", "--iterations NUMBER", "number of iterations per user simulator") do |n|
    worker_iterations = n.to_i
  end
  opts.on("-n", "--num-workers NUMBER", "number of user simulators") do |n|
    workers = n.to_i
  end
  opts.on("-s", "--num-startup-iters NUMBER", "number of startup/shutdown iterations") do |n|
    startup_iters = n.to_i
  end
  opts.on("-w", "--warmup NUMBER", "number of warm-up iterations") do |n|
    warmup_iterations = n.to_i
  end
  opts.on("-p", "--port NUMBER", "port number for test Rails server") do |n|
    port_num = n.to_i
  end
end.parse!

# Make the constant accessible inside the method definitions
PORT_NUM = port_num

def get_rails_server_pid
  ps_out = `ps | grep -v grep | grep bin/rails | grep #{PORT_NUM}`
  if ps_out.strip =~ /(\d+)/
    $1.to_i
  else
    nil
  end
end

def clean_server_for_startup
  server_pid = get_rails_server_pid
  if server_pid
    print "Existing Rails server found on port #{PORT_NUM}, killing PID #{server_pid.inspect}.\n"
    Process.kill "KILL", server_pid
  end
end

def server_start
  # Start the server
  fork do
    STDERR.print "In PID #{Process.pid}, starting server on port #{PORT_NUM}\n"
    system "cd work/discourse && RAILS_ENV=profile puma -p #{PORT_NUM}"
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
    output = `curl -f http://localhost:#{PORT_NUM}/ 2>/dev/null`
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
      output = `curl -f http://localhost:#{PORT_NUM}/ 2>/dev/null`
      if $?.success?
        yield
        return
      else
        failed_iters += 1
      end
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
  RestClient.get "http://localhost:#{PORT_NUM}/benchmark/simple_request"
  (Time.now - t0).to_f
end

print "Checking for previous running Rails server...\n"
clean_server_for_startup

# One Burn-in Iteration
print "Starting and stopping server to preload caches...\n"
full_iteration_start_stop

print "Running start-time benchmarks for #{startup_iters} iterations...\n"
startup_times = (1..startup_iters).map { full_iteration_start_stop }
request_times = nil

# TODO: fork workers *before* starting timer, then send data over a pipe to each of them to begin.

children = {}

# TODO: actually check user IDs in database. Right now, I assume we're dropping-and-recreating with the DB seed script.

worker_times = []

with_running_server do

  (1..workers).map do |worker_num|
    pid = fork do
      cmd = "/usr/bin/env ruby ./user_simulator.rb -o #{worker_num} -r #{random_seed + 100 * worker_num} -n #{worker_iterations} -w 0 -d 0 -p #{PORT_NUM}"
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

    print "Child PID #{finished_pid.inspect} completed, elapsed time: #{children[finished_pid][:elapsed].inspect}, status: #{children[finished_pid][:status].inspect}\n"
  end

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
end # Stop the Rails server after all user simulators have exited.

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
