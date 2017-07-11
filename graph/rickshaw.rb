#!/usr/bin/env ruby

require "json"
require "erubis"

templates = Dir["*.html.erb"].to_a

if ARGV.include?["-t"]
  idx = ARGV.index("-t")
  ARGV.delete(idx)
  templates = ARGV.delete(idx).split(",")
end

raise "Wrong number of arguments!" if ARGV.size != 1
input_data = JSON.load File.read(ARGV[0])

output_path = nil # Set the scope for this local

templates.each do |t|
  output_path = File.basename(t) + ".html"

  er = Erubis::Eruby.new File.read(t)

  output = er.result :data => input_data

  File.open(output_path, "w") do |f|
    f.print output
  end
end

# One template? Open the result in Chrome
if templates.size == 1
  print "Opening #{output_path.inspect} in Chrome..."
  system "open -a \"Google Chrome.app\" #{OUTPUT_FILE}"
  if $?.success?
    print " (Succeeded!)\n"
  else
    print " (Failed! #{$?.to_i})\n"
  end
end
