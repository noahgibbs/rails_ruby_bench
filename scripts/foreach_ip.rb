#!/usr/bin/env ruby

raise "Provide exactly one argument!" if ARGV.size != 1

ips = File.read("#{ENV["HOME"]}/multi_inst_ips.txt").split("\n").map(&:strip)
puts "IPs: #{ips.inspect}, arg: #{ARGV[0]}"

arg = ARGV[0]

if arg["0.0.0.0"]
  ips.each do |ip|
    real_arg = arg.gsub("0.0.0.0", ip)
    system real_arg
  end
else
  ips.each do |ip|
    system "#{arg} #{ip}"
  end
end

