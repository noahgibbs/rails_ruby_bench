#!/usr/bin/env ruby

# Simple example runner script, editable for different uses

RUBIES = [
  #"2.5.3",
  "2.6.6",
  "2.7.1",
  "ext-new_fake_2.8",
]

TESTS = [
  "gem install bundler -v 1.17.3 && bundle _1.17.3_ && bundle _1.17.3_ exec ./start.rb -i 15000 -w 1000 -s 0 --no-warm-start -o data/",
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
    invocation = "rvm use #{ruby} && export RUBY_RUNNER_TEST_INDEX=#{test_index} && #{test}"
    commands.concat([invocation] * TIMES)
  end
end

rand_commands = commands.shuffle

rand_commands.each do |command|
  csystem(command, "Error running test!", bash: true, to_console: true)
end

csystem("touch #{ENV["HOME"]}/run_finished.txt", "Error creating run-finished file!", bash: false, to_console: true)
