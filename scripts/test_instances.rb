#!/usr/bin/env ruby

require "json"

launch_ami = 'ami-0e7a9d0f34bbb44e9'
inst_name = ENV['INSTANCE_NAME'] || 'RRBMultiTestInstance'
inst_type = ENV['INSTANCE_TYPE'] || 'm4.2xlarge'
inst_count = ENV['INSTANCE_COUNT'] || 1
placement = ENV['PLACEMENT'] ? "--placement #{ENV['PLACEMENT']}" : "" # --placement Tenancy=dedicated
json_out = `aws ec2 run-instances --count #{inst_count} --instance-type #{inst_type} --key-name rrb-1 #{placement} --image-id #{launch_ami} --tag-specifications 'ResourceType=instance,Tags=[{Key=InstTypeComment,Value=#{inst_name}}]'`

ec2_info = JSON.parse(json_out)
# File.open("#{ENV["HOME"]}/multi_inst_json.txt", "w") { |f| f.write JSON.pretty_generate(ec2_info) }

ids = ec2_info["Instances"].map { |i| i["InstanceId"] }.join(" ")
cmd_lines = <<LINES
aws ec2 terminate-instances --instance-ids #{ids}
LINES

File.open("#{ENV["HOME"]}/multi_inst_terminate.txt", "w") { |f| f.puts cmd_lines }

ec2_info["Instances"].each_with_index do |instance, index|
    id = instance["InstanceId"]
    ec2_type = instance["InstanceType"]

    inst_ip = `aws ec2 describe-instances --instance-ids #{id} --query 'Reservations[*].Instances[*].PublicIpAddress' --output text`.strip
    instance["ip"] = inst_ip

    puts "Launched EC2 instance: #{ec2_type.inspect} / #{id.inspect}"
    cmd_lines = <<LINES
ssh -i ~/.ssh/rrb-1.pem ubuntu@#{inst_ip}
scp -i ~/.ssh/rrb-1.pem ubuntu@#{inst_ip}:~/rails_ruby_bench/data/*.json .
scp -i ~/.ssh/rrb-1.pem ubuntu@#{inst_ip}:~/rsb/data/*.json .
aws ec2 terminate-instances --instance-ids #{id}
LINES
    puts cmd_lines
    File.open("#{ENV["HOME"]}/multi_inst_commands_#{index}.txt", "w") { |f| f.puts(cmd_lines) }
end

File.open("#{ENV["HOME"]}/multi_inst_ips.txt", "w") { |f| f.puts ec2_info["Instances"].map { |i| i["ip"] } }
