#!/usr/bin/env ruby

require "json"

# While you might get some useful ideas here, this script is *not* general-purpose
# and will *not* do exactly what you wish it would. It's pretty specific to my workflow.

latest_ami = 'ami-052d56f9c0e718334'
inst_name = ENV['INSTANCE_NAME'] || 'RailsRubyBenchTestInstance'
inst_type = ENV['INSTANCE_TYPE'] || 'm4.2xlarge'
json_out = `aws ec2 run-instances --count 1 --instance-type #{inst_type} --key-name noah-packer-1 --placement Tenancy=dedicated --image-id #{latest_ami} --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=#{inst_name}}]'`

ec2_info = JSON.parse(json_out)

# This is really not a sensible way to handle multiple instances (which I don't use currently)
ec2_info["Instances"].each do |instance|
    id = instance["InstanceId"]
    ec2_type = instance["InstanceType"]

    inst_ip = `aws ec2 describe-instances --instance-ids #{id} --query 'Reservations[*].Instances[*].PublicIpAddress' --output text`.strip

    puts "Launched EC2 instance: #{ec2_type.inspect} / #{id.inspect}"
    cmd_lines = <<LINES
ssh -i ~/.ssh/noah-packer-1.pem ubuntu@#{inst_ip}
scp -i ~/.ssh/noah-packer-1.pem ubuntu@#{inst_ip}:~/rails_ruby_bench/data/*.json .
scp -i ~/.ssh/noah-packer-1.pem ubuntu@#{inst_ip}:~/rsb/data/*.json .
aws ec2 terminate-instances --instance-ids #{id}

AppFolio only: assume-role appfolio-dev User MFA_TOKEN
LINES
    puts cmd_lines
    File.open("#{ENV["HOME"]}/rrb_commands.txt", "w") { |f| f.puts(cmd_lines) }
end
