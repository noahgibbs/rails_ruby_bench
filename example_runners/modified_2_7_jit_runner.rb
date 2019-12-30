#!/usr/bin/env ruby

# Simple example runner script, editable for different uses

RUBIES = [
  #"2.7.0-preview2",
  #"2.7.0-preview3",
  #"ext-mri-head-018be4",
  #"ext-mri-head-046be6",
  #"ext-mri-head-a51583",
  #"ext-mri-head-bd3463",
  #"ext-mri-head-d47b64",
  #"ext-mri-head-7750ed",
  #"ext-mri-head-597ec4",
  #"ext-mri-head-cd706c",
  #"ext-mri-head-ff767d",
  #"ext-mri-head-958d95",
  #"ext-mri-head-14b5c4",
  #"ext-mri-head-a5448c",

  #"ext-mri-head-853d91",
  #"ext-mri-head-bea322",

  #"ext-mri-head-929a4a",
  #"ext-mri-head-74bb8f",
  #"ext-mri-head-c7632f",
  #"ext-mri-head-1390d5",
  #"ext-mri-head-853d91",
  #"ext-mri-head-19f91f",
  #"ext-mri-head-652800",
  #"ext-mri-head-07f206",

  "ext-mri-head-853d91",
  "ext-mri-head-7c0730",
  "ext-mri-head-6ff125",
  "ext-mri-head-1390d5",
  "ext-mri-head-886938",
  "ext-mri-head-30a74a",
  "ext-mri-head-c7632f",
  "ext-mri-head-ebbe39",
  "ext-mri-head-7c3bc0",

]

TESTS = [
  "bundle _1.17.3_ exec ./start.rb -i 10000 -w 1000 -s 0 --no-warm-start -o data/",
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

RUBIES.each do |ruby|
  csystem("rvm use #{ruby} && gem install bundler -v 1.17.3 && bundle _1.17.3_", "Couldn't install gems in #{ruby}!", bash: true, to_console: true)
  csystem("cp ordered_options.rb /home/ubuntu/.rvm/gems/#{ruby}/gems/activesupport-4.2.8/lib/active_support/", "Error copying ordered_options.rb!")
end

commands = []
RUBIES.each do |ruby|
  TESTS.each_with_index do |test, test_index|
    invocation_no_jit = "rvm use #{ruby} && export RRB_WITH_JIT=NO && export RRB_RUNNER_TEST_INDEX=#{test_index} && #{test}"
    commands.concat([invocation_no_jit] * TIMES)
  end
end

rand_commands = commands.shuffle

rand_commands.each do |command|
  csystem(command, "Error running test!", bash: true, to_console: true)
  csystem("rm work/discourse/log/profile.log", "Error removing logfile", bash: false, to_console: true)
end
