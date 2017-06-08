#!/usr/bin/env ruby

# Start the Rails server and measure time to first request (only).

# If needed: "gem install rest-client"
require 'rest-client'

PORT_NUM = 4567

# Checked system - error if the command fails
def csystem(cmd, err)
  out = `#{cmd}`
  #print "Running command: #{cmd.inspect}\n" if opts[:debug] || opts["debug"]
  unless $?.success?
    print "Error running command:\n#{cmd.inspect}\nOutput:\n#{out}\n=====\n"
    raise err
  end
  #print "Command output:\n#{out}\n=====\n" if opts[:debug] || opts["debug"]
  out
end

def server_start
  # Start the server
  @started_pid = fork do
    STDERR.print "In PID #{Process.pid}, starting server on port #{PORT_NUM}\n"
    #Dir.chdir "work/discourse"
    # Start Puma in a new process group to easily kill subprocesses if necessary
    exec("bundle", "exec", "puma", "-p", PORT_NUM.to_s, :pgroup => true)
  end
end

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

def time_to_first_req
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

def full_iteration_start_stop
  elapsed = nil
  with_started_server do
    print "Server is started, running start/stop iteration...\n"
    server_output, elapsed = time_to_first_req
  end
  elapsed.to_f
end

# One Burn-in Iteration
#print "Starting and stopping server to preload caches...\n"
#full_iteration_start_stop

print "Running start-time benchmarks...\n"
startup_times = (1..11).map { full_iteration_start_stop }

print "Startup times: #{startup_times.inspect}\n"

print "Mean startup time: #{startup_times.inject(0.0, &:+) / startup_times.size}\n"
print "Median startup time: #{startup_times.sort[5]}\n"
