#!/usr/bin/env ruby

# This script, when run on an RRB EC2 instance, will attempt to build
# the given Ruby SHA in a predetermined way.

if ARGV.size != 1
  raise "Error - provide exactly one SHA as the only argument!"
end

SHA = ARGV[0]
SHORT_SHA = SHA[0..5]
INSTALL_DIR = "/home/ubuntu/install/mri-head-#{SHA}"
File.mkdir_p INSTALL_DIR

# Checked system - error if the command fails
def csystem(cmd, err = nil, opts = {})
  #cmd = "bash -l -c \"#{cmd}\"" if opts[:bash] || opts["bash"]
  print "Running command: #{cmd.inspect}\n"
  system(cmd, out: $stdout, err: :out)
  unless $?.success? # || opts[:fail_ok] || opts["fail_ok"]
    puts "Error running command:\n#{cmd.inspect}"
    puts "Output:\n#{out}\n=====" if out
    raise (err || "Error running command #{cmd.inspect}"
  end
end

Dir.chdir("/home/ubuntu/rails_ruby_bench/work/mri-head") do
  csystem("git pull")
  csystem("git checkout #{SHA}")
  csystem("./configure --prefix=#{INSTALL_DIR}")
  csystem("make clean && make && make install")
  csystem("rvm mount #{INSTALL_DIR} -n mri-head-#{SHORT_SHA}")
end
