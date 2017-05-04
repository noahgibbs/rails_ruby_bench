#!/usr/bin/env ruby

# Start the Rails server and measure time to first request and request processing times.

require 'optparse'
require 'rest-client'
require 'json'
require 'gabbler'  # Require this before requiring Rails' config/environment.rb, which will start Bundler.

# Run this in "profile" environment for Discourse.
ENV['RAILS_ENV'] = 'profile'
require File.expand_path(File.join(File.dirname(__FILE__), "work/discourse/config/environment"))

startup_iters = 2
random_seed = 16541799507913229037  # Chosen via irb and '(1..20).map { (0..9).to_a.sample }.join("")'
worker_iterations = 1500  # All iterations, spread between load-test worker threads
warmup_iterations = 0  # Need to test warmup iterations properly...
workers = 30
port_num = 4567
out_dir = "/tmp"
puma_processes = 10
puma_threads = 6

OptionParser.new do |opts|
  opts.banner = "Usage: ruby start.rb [options]"
  opts.on("-r", "--random-seed NUMBER", "random seed") do |r|
    random_seed = r.to_i
  end
  opts.on("-i", "--iterations NUMBER", "number of iterations per user simulator") do |n|
    worker_iterations = n.to_i
  end
  opts.on("-n", "--num-workers NUMBER", "number of user simulator worker threads") do |n|
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
  opts.on("-o", "--out-dir DIRECTORY", "directory to write JSON output to") do |d|
    out_dir = d
  end
  opts.on("-t", "--threads-per-server NUMBER", "number of Puma threads per server process") do |t|
    puma_threads = t.to_i
  end
  opts.on("-c", "--cluster-processes NUMBER", "number of Puma processes in cluster mode") do |c|
    puma_processes = c.to_i
  end
end.parse!

raise "No such output directory!" unless File.directory?(out_dir)

# Make the constant accessible inside the method definitions
PORT_NUM = port_num
PUMA_THREADS = puma_threads
PUMA_PROCESSES = puma_processes
RANDOM_SEED = random_seed

DISCOURSE_REVISION = `cd work/discourse && git rev-parse HEAD`.chomp

def server_start
  # Start the server
  @started_pid = fork do
    STDERR.print "In PID #{Process.pid}, starting server on port #{PORT_NUM}\n"
    Dir.chdir "work/discourse"
    # Start Puma in a new process group to easily kill subprocesses if necessary
    exec({ "RAILS_ENV" => "profile" }, "puma", "-p", PORT_NUM.to_s, "-w", PUMA_PROCESSES.to_s, "-t", "0:#{PUMA_THREADS}", :pgroup => true)
  end
end

# TODO: Proper audit on this code. Right now it assumes no child processes means no Rails server running, which isn't quite right.

def server_stop
  Process.kill("-INT", @started_pid)
  print "server_stop: Interrupted Rails server at expected PID #{@started_pid.inspect}.\n"
  loop do
    # Verify that server we started is sufficiently dead before we restart
    STDERR.print "Waiting for dead PID expecting #{@started_pid.inspect}\n"
    dead_pid = Process.waitpid
    STDERR.print "Got dead pid: #{dead_pid.inspect}\n"
    break if dead_pid == @started_pid
  end
  @started_pid = nil
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
        raise "Too many failed iterations!" if failed_iters > 5_000
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

require_relative "user_simulator"

# One Burn-in Iteration
print "Starting and stopping server to preload caches...\n"
full_iteration_start_stop

print "Running start-time benchmarks for #{startup_iters} iterations...\n"
startup_times = (1..startup_iters).map { full_iteration_start_stop }
request_times = nil

worker_times = []
warmup_times = []

with_running_server do
  print "Warmup iterations...\n"
  # First, warmup iterations.
  warmup_times = multithreaded_actions(warmup_iterations, workers, PORT_NUM) if warmup_iterations != 0
  # Second, real iterations.
  print "Real iterations...\n"
  worker_times = multithreaded_actions(worker_iterations, workers, PORT_NUM) if worker_iterations != 0
end # Stop the Rails server after all user simulators have exited.

print "===== Startup Benchmarks =====\n"
print "Longest run: #{startup_times.max}\n"
print "Shortest run: #{startup_times.min}\n"
print "Mean: #{startup_times.inject(0.0, &:+) / startup_times.size}\n"
print "Median: #{startup_times.sort[ startup_times.size / 2 ] }\n"
print "Raw times: #{startup_times.inspect}\n"

print "===== Startup Benchmarks =====\n"
worker_times_max = worker_times.map(&:max)
print "Slowest thread run: #{worker_times_max.max}\n"
print "Fastest thread run: #{worker_times_max.min}\n"
print "Mean thread run: #{worker_times_max.inject(0.0, &:+) / worker_times.size}\n"
print "Median thread run: #{worker_times_max.sort[ worker_times.size / 2 ] }\n"
print "Raw times: #{worker_times.inspect}\n"

test_data = {
  "settings" => {
    "startup_iters" => startup_iters,
    "random_seed" => random_seed,
    "worker_iterations" => worker_iterations,
    "warmup_iterations" => warmup_iterations,
    "workers" => workers,
    "puma_processes" => puma_processes,
    "puma_threads" => puma_threads,
    "port_num" => port_num,
    "out_dir" => out_dir,
    "discourse_revision" => DISCOURSE_REVISION,
  },
  "environment" => {
    "RUBY_VERSION" => RUBY_VERSION,
  },
  "startup" => {
    "times" => startup_times
  },
  "warmup" => {
    "times" => warmup_times
  },
  "requests" => {
    "times" => worker_times
  },
}

json_filename = "#{out_dir}/rails_ruby_bench_#{Time.now.to_i}.json"
File.open(json_filename, "w") do |f|
  f.print JSON.pretty_generate(test_data)
  f.print "\n"
end
print "Wrote run data to #{json_filename}.\n"
