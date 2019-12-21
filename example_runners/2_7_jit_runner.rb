#!/usr/bin/env ruby

# Simple example runner script, editable for different uses

RUBIES = [
  "2.6.0",
  "2.7.0-rc1",
]

TESTS = [
  "gem install bundler -v 1.17.3 && bundle _1.17.3_ && bundle _1.17.3_ exec ./start.rb -i 10000 -w 1000 -s 0 --no-warm-start -o data/",
]

TIMES = 30

# Checked system - error if the command fails
def csystem(cmd, err, opts = {})
  cmd = "bash -l -c \"#{cmd}\"" if opts[:bash] || opts["bash"]
  print "Running command: #{cmd.inspect}\n" if opts[:to_console] || opts["to_console"] || opts[:debug] || opts["debug"]
  if opts[:to_console] || opts["to_console"]
    system(cmd, out: $stdout, err: :out)
  else
    out = `#{cmd}`
  end
  unless $?.success? || opts[:fail_ok] || opts["fail_ok"]
    puts "Error running command:\n#{cmd.inspect}"
    puts "Output:\n#{out}\n=====" if out
    raise err
  end
end

commands = []
RUBIES.each do |ruby|
  TESTS.each_with_index do |test, test_index|
    # For JIT, set RUBYOPT to turn JIT on. For either JIT or non-JIT, set a RRB_WITH_JIT variable that gets picked up in 'environment' because it has RUBY in the name.
    invocation_jit = "rvm use #{ruby} && export RRB_WITH_JIT=YES && export RUBYOPT='--jit' && export RRB_RUNNER_TEST_INDEX=#{test_index} && #{test}"
    invocation_no_jit = "rvm use #{ruby} && export RRB_WITH_JIT=NO && export RRB_RUNNER_TEST_INDEX=#{test_index} && #{test}"
    commands.concat([invocation_no_jit,invocation_jit] * TIMES)
  end
end

rand_commands = commands.sample(commands.size)

rand_commands.each do |command|
  csystem(command, "Error running test!", bash: true, to_console: true)
end
