#!/usr/bin/env ruby

require "json"

json_out = `aws ec2 run-instances --count 1 --instance-type m4.2xlarge --key-name noah-packer-1 --placement Tenancy=dedicated --image-id ami-086666f4fee1175fb --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=RailsRubyBenchTestInstance}]'`

ec2_info = JSON.parse(json_out)

ec2_info["Instances"].each do |instance|
    id = instance["InstanceId"]
    ec2_type = instance["InstanceType"]

    inst_ip = `aws ec2 describe-instances --instance-ids #{id} --query 'Reservations[*].Instances[*].PublicIpAddress' --output text`.strip

    puts "Launched EC2 instance: #{ec2_type.inspect} / #{id.inspect}"
    puts "ssh -i ~/.ssh/noah-packer-1.pem ubuntu@#{inst_ip}"
    puts "scp -i ~/.ssh/noah-packer-1.pem ubuntu@#{inst_ip}~/rails_ruby_bench/data/*.json ."
    puts "scp -i ~/.ssh/noah-packer-1.pem ubuntu@#{inst_ip}~/rsb/data/*.json ."
end
