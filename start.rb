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
warmup_iterations = 300  # Need to test warmup iterations properly...
workers = 30
port_num = 4567
out_dir = "."
out_file = nil
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
  opts.on("-f", "--out-file FILENAME", "filename to write JSON output to") do |f|
    out_file = f
  end
  opts.on("-t", "--threads-per-server NUMBER", "number of Puma threads per server process") do |t|
    puma_threads = t.to_i
  end
  opts.on("-c", "--cluster-processes NUMBER", "number of Puma processes in cluster mode") do |c|
    puma_processes = c.to_i
  end
end.parse!

raise "No such output directory as #{out_dir.inspect}!" unless File.directory?(out_dir)

# Make the constant accessible inside the method definitions
PORT_NUM = port_num
PUMA_THREADS = puma_threads
PUMA_PROCESSES = puma_processes
RANDOM_SEED = random_seed

CONTROL_PORT = 9939
CONTROL_TOKEN = "VeryModelOfAModernMajorGeneral"

class BenchmarkSystemError < RuntimeError; end

# Checked system - error if the command fails
def csystem(cmd, err, opts = {})
  out = `#{cmd}`
  print "Running command: #{cmd.inspect}\n" if opts[:debug] || opts["debug"]
  unless $?.success? || opts[:fail_ok] || opts["fail_ok"]
    print "Error running command:\n#{cmd.inspect}\nOutput:\n#{out}\n=====\n"
    raise BenchmarkSystemError.new(err)
  end
  print "Command output:\n#{out}\n=====\n" if opts[:debug] || opts["debug"]
  out
end

def last_pid
  @started_pid
end

def get_server_rss
  # TODO: get all processes with the name "cluster worker <num>: <master pid> [discourse]"
  1024 * BigDecimal.new(`ps -o rss= -p#{@started_pid}`)
end

def get_server_gc_stats
  # NOTE: This won't work until a version of Puma later than 3.9.1 (3.11.0 has it). So for now, don't use this.
  output = `bundle exec pumactl --control-url tcp://127.0.0.1:#{CONTROL_PORT} --control-token #{CONTROL_TOKEN} gc-stats`
  output.sub!(/^[^{]+/, "")
  JSON.parse(output.chomp)
end

def server_start
  # Start the server
  @started_pid = fork do
    STDERR.print "In PID #{Process.pid}, starting server on port #{PORT_NUM}\n"
    Dir.chdir "work/discourse"
    # Start Puma in a new process group to easily kill subprocesses if necessary
    exec({ "RAILS_ENV" => "profile" }, "bundle", "exec", "puma", "--control", "tcp://127.0.0.1:#{CONTROL_PORT}", "--control-token", CONTROL_TOKEN, "-p", PORT_NUM.to_s, "-w", PUMA_PROCESSES.to_s, "-t", "1:#{PUMA_THREADS}", :pgroup => true)
  end
end

def server_stop
  begin
    csystem "RAILS_ENV=profile bundle exec pumactl --control-token #{CONTROL_TOKEN} --control-url tcp://127.0.0.1:#{CONTROL_PORT} halt", "Error trying to stop Puma via pumactl!"
  rescue BenchmarkSystemError
    # Error stopping w/ pumactl, try just killing the process
    Process.kill("-INT", @started_pid)
  end
  print "server_stop: Asked Puma to stop, expected PID #{@started_pid.inspect}.\n"
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
      sleep 0.1
      output = `curl -f http://localhost:#{PORT_NUM}/ 2>/dev/null`
      if $?.success?
        yield
        return
      else
        failed_iters += 1
        if failed_iters % 10 == 0
          puts "Tenth failed iter output:\n#{output}\n==========="
        end
        raise "Too many failed iterations!" if failed_iters > 50
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

Signal.trap("HUP") do
  print "Ignoring SIGHUP...\n"
end

# One Burn-in Iteration
print "Starting and stopping server to preload caches...\n"
full_iteration_start_stop

print "Running start-time benchmarks for #{startup_iters} iterations...\n"
startup_times = (1..startup_iters).map { full_iteration_start_stop }
request_times = nil

worker_times = []
warmup_times = []

# Make sure these are in scope
loaded_rss = nil
final_rss = nil
first_gc_stat = nil
last_gc_stat = nil

with_running_server do
  loaded_rss = get_server_rss
  #first_gc_stat = get_server_gc_stats

  # By randomizing all "real" actions before all warmups, we guarantee
  # that multiple runs with different numbers of warmups but the same
  # number of worker iterations will always run the same worker
  # *actions* for that number of iterations.  But we always want to
  # *run* warmup actions *first*, even if we *randomize* them
  # *second.*
  worker_actions = actions_for_iterations(worker_iterations)
  warmup_actions = actions_for_iterations(warmup_iterations)

  # First, warmup iterations.
  print "Warmup iterations: #{warmup_iterations}\n"
  unless warmup_iterations == 0
    warmup_times = multithreaded_actions(warmup_actions, workers, PORT_NUM)
  end
  # Second, real iterations.
  print "Benchmark iterations: #{worker_iterations}\n"
  unless worker_iterations == 0
    worker_times = multithreaded_actions(worker_actions, workers, PORT_NUM)
  end
  final_rss = get_server_rss
  #last_gc_stat = get_server_gc_stats
end # Stop the Rails server after all interactions have finished.

# TODO: Fix these thread run times. process.rb was fixed, the just-to-console times weren't.
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

env_vars = ENV.keys
important_env_vars = env_vars.select { |name| name.downcase["ruby"] || name.downcase["gem"] } + [ "LD_PRELOAD" ]
env_hash = {}
important_env_vars.each { |var| env_hash["env-#{var}"] = ENV[var] }

test_data = {
  "version" => 2,
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
    "out_file" => out_file || false,
    "discourse_revision" => `cd work/discourse && git rev-parse HEAD`.chomp,
  },
  "environment" => {
    "RUBY_VERSION" => RUBY_VERSION,
    "RUBY_DESCRIPTION" => RUBY_DESCRIPTION,
    "rvm current" => `rvm current 2>&1`.strip,
    "discourse git status" => `cd work/discourse && git status`,
    "discourse git sha" => `cd work/discourse && git rev-parse HEAD`.chomp,
    "rails_ruby_bench git status" => `git status`,
    "rails_ruby_bench git sha" => `git rev-parse HEAD`,
    "ec2 instance id" => `wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`,
  }.merge(env_hash),
  "startup" => {
    "times" => startup_times
  },
  "warmup" => {
    "times" => warmup_times
  },
  "requests" => {
    "times" => worker_times
  },
  "memory" => {
    "loaded_rss" => loaded_rss,
    "final_rss" => final_rss,
    #"gc_stat_last" => last_gc_stat,
    #"gc_stat_first" => first_gc_stat,
  },
}

json_filename = File.join(out_dir, out_file || "rails_ruby_bench_#{Time.now.to_i}.json")
print "Writing run data to #{json_filename}...\n"
File.open(json_filename, "w") do |f|
  f.print JSON.pretty_generate(test_data)
  f.print "\n"
end
print "Wrote run data to #{json_filename}\n"
