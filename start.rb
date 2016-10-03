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

server_pid = get_rails_server_pid
if server_pid
  puts "Existing Rails server found on port 4567, killing PID #{server_pid.inspect}."
  Process.kill "KILL", server_pid
end

# Start the server
fork do
  system "cd MarkApp && RAILS_ENV=production rails server -p 4567"
end

elapsed = nil
output = nil

t0 = Time.now
loop do
  sleep 0.01
  output = `curl -f http://localhost:4567/benchmark/start 2>/dev/null`
  next unless $?.success?
  elapsed = Time.now - t0
  break
end

server_pid = get_rails_server_pid
if server_pid
  Process.kill("INT", server_pid)
  puts "Interrupted Rails server at PID #{server_pid.inspect}."
else
  puts "No Rails server found, not killing."
end
puts "Output:\n#{output}"
puts "Elapsed: #{elapsed.to_f.inspect} seconds"
