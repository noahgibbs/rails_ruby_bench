#!/usr/bin/env ruby

# Start the Rails server and measure time to first request.

# Start the server
server_pid = fork do
  system "cd MarkApp && RAILS_ENV=production rails server"
end

elapsed = nil
output = nil

loop do
  sleep 0.05
  t0 = Time.now
  output = `curl -f http://localhost:3000/start_benchmark`
  next unless $?.success?
  elapsed = Time.now - t0
  break
end

Process.kill "KILL", server_pid
puts "Killed Rails server..."
puts "Output:\n#{output}"
