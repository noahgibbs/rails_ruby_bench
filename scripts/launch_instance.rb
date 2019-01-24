#!/usr/bin/env ruby

require "json"

# While you might get some useful ideas here, this script is *not* general-purpose
# and will *not* do exactly what you wish it would. It's pretty specific to my workflow.

json_out = `aws ec2 run-instances --count 1 --instance-type m4.2xlarge --key-name noah-packer-1 --placement Tenancy=dedicated --image-id ami-00247b9bfae81953c --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=RailsRubyBenchTestInstance}]'`

ec2_info = JSON.parse(json_out)

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
LINES
    puts cmd_lines
    File.open("#{HOME}/rrb_commands.txt", "w") { |f| f.puts(cmd_lines) }
end
