#!/usr/bin/env ruby

raise "Provide exactly one argument!" if ARGV.size != 1

ips = File.read("#{ENV["HOME"]}/multi_inst_ips.txt").split("\n").map(&:strip)

arg = ARGV[0]
threads = []

ips.each do |ip|
    t = Thread.new do
        if arg["0.0.0.0"]
            real_arg = arg.gsub("0.0.0.0", ip)
            system real_arg
        else
            system "#{arg} #{ip}"
        end
    end
    threads << t
end

threads.each { |t| t.join }
