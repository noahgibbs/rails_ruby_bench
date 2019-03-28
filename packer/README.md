# Using Packer to Build an AMI

Instead of using a pre-built AMI, you can build your own.

This only builds a combined AMI, with the load-tester, database and Rails server on the same instance. You're welcome to adapt it to other configurations, though, if you'd like to benchmark in that configuration. I'd love a Pull Request!

To build your own AMI, the usual invocation is "packer build ami.json" from this directory.

# Passenger Enterprise

Passenger Enterprise is *not* included in the default ami.json. There
is a file called ami-with-passenger-enterprise.json. You'll also need
two more files called passenger-enterprise-license and
passenger-download-token, with the license and download codes you
received when you purchased Passenger Enterprise.

If you run this without those codes, you can't build an AMI with
Passenger Enterprise on it. You shouldn't need a production
(user-facing) license for this. But given that you're benchmarking,
you usually won't want to spend money on a Passenger Enterprise
license. It's not in the default image, and I can't hand out Passenger
license codes in any case.

# Installing Packer

Packer is annoyingly unfriendly to most packaging systems. On Linux, they just want you to download and manually install the Packer binary from their site.

On Mac, Homebrew has a package for it which just does the same thing. But at least Homebrew will do it for you:

    brew install packer

# Getting Your AWS Account Set Up

See Packer's documentation on building AMIs: https://www.packer.io/intro/getting-started/build-image.html

The short answer is that you can install the AWS credentials in the
standard ways and Packer will use them. For Mac OS, you can use homebrew:

    brew install aws-cli
    aws configure

## Canonical Benchmark Timing

The region shouldn't matter much, but I recommend us-east-1 -- it's the cheapest, and this benchmark shouldn't need locality to any specific world location. You need to build an AMI in the specific region where you'll be testing.

However, you do *not* need to build an AMI with the exact same instance type where you'll be benchmarking. So you can save a few pennies when building your instance, if you want.

If you build an AMI and keep it in your account, that may also cost around $0.01 USD/month (plus the initial $0.02 when you build it.) So if you don't need to preserve it, delete it. I don't know if that's still true for a free AWS account, so YMMV.

If you want more realistic performance numbers... Well, a benchmark may not be your best bet. But you *can* configure these processes to run on multiple instances, which will exchange some sources of error for other ones. However, I don't supply AMI build scripts for separate instances for database, load-tester, etc, nor do I supply a way to coordinate them. You'll need to set that up for yourself. It's not hard if you're used to setting up multi-instance Rails apps - Discourse is pretty standard in how it gets set up.

## Configuring Your AMI

When choosing a source AMI, you'll need to match the region you're building in. Building in us-east-1? Use a us-east-1 AMI. I recommend Packer's EBS builder, but then you'll need to use EBS instead of instance store. And if you build on a cheap instance like t2.micro, you can probably only use an HVM AMI (fully virtualized.) To build a ParaVirtualized (PV) AMI, I think you'll need to build your AMI from a ParaVirtualized source AMI -- feel free to correct me if I'm wrong in the form of a Pull Request or Issue :-)

You don't need to fully match the final instance size for the benchmark when you build your AMI. Though if you match it 100%, it'll certainly be compatible. The only reason I don't match them up perfectly is that it's generally cheaper to build your AMI on a smaller instance when you can.

## IAM Roles

See Packer's documentation on setting up AWS and IAM roles: https://www.packer.io/docs/builders/amazon.html

Also:

    {
      "Version": "2012-10-17",
      "Statement": [{
          "Effect": "Allow",
          "Action" : [
            "ec2:AttachVolume",
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:CopyImage",
            "ec2:CreateImage",
            "ec2:CreateKeypair",
            "ec2:CreateSecurityGroup",
            "ec2:CreateSnapshot",
            "ec2:CreateTags",
            "ec2:CreateVolume",
            "ec2:DeleteKeypair",
            "ec2:DeleteSecurityGroup",
            "ec2:DeleteSnapshot",
            "ec2:DeleteVolume",
            "ec2:DeregisterImage",
            "ec2:DescribeImageAttribute",
            "ec2:DescribeImages",
            "ec2:DescribeInstances",
            "ec2:DescribeRegions",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeSnapshots",
            "ec2:DescribeSubnets",
            "ec2:DescribeTags",
            "ec2:DescribeVolumes",
            "ec2:DetachVolume",
            "ec2:GetPasswordData",
            "ec2:ModifyImageAttribute",
            "ec2:ModifyInstanceAttribute",
            "ec2:ModifySnapshotAttribute",
            "ec2:RegisterImage",
            "ec2:RunInstances",
            "ec2:StopInstances",
            "ec2:TerminateInstances"
          ],
          "Resource" : "*"
      }]
    }

