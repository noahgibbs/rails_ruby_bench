#!/usr/bin/env ruby

RAILS_BENCH_DIR = "/var/rails_ruby_bench"

class DockerBuildError < RuntimeError; end

# Checked system - error if the command fails
def csystem(cmd, err, opts = {})
  cmd = "bash -l -c \"#{cmd}\"" if opts[:bash]
  print "Running command: #{cmd.inspect}\n" if opts[:debug] || opts["debug"]
  system(cmd, out: $stdout, err: :out)
  unless $?.success? || opts[:fail_ok] || opts["fail_ok"]
    puts "Error running command:\n#{cmd.inspect}"
    raise DockerBuildError.new(err)
  end
end

# And check to make sure the benchmark actually runs... But just do a few iterations.
Dir.chdir(RAILS_BENCH_DIR) do
  begin
    csystem "./start.rb -s 1 -n 1 -i 10 -w 0 -o /tmp/ -c 1", "Couldn't successfully run the benchmark!", :bash => true
  rescue DockerBuildError
    # Before dying, let's look at that Rails logfile... Redirect stdout to stderr.
    print "Error running test iterations of the benchmark, printing Rails log to console!\n==========\n"
    print `tail -60 work/discourse/log/profile.log`   # If we echo too many lines they just get cut off by Packer
    print "=============\n"
    raise # Re-raise the error, we still want to die.
  end
end
