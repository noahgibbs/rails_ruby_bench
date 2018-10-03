# Rails Ruby Bench

Rails Ruby Bench (aka RRB) is a Discourse-based benchmark to measure
the speed of the Ruby language. It can incidentally be used to measure
the speed of a number of other things.

RRB is a "Real World" benchmark, in the sense of running a large Rails
app in a concurrent configuration with a lot of complexity and
variation in what it does. That makes it wonderful for measuring
end-to-end effects of significant changes, and terrible for optimizing
operations that don't take a lot of runtime.

This Discourse-based benchmark steals some code from Discourse
(e.g. user\_simulator.rb, seed\_db\_data.rb), so it's licensed GPLv2.

There are two supported ways to run this benchmark: AWS and Docker. If
you want to do local development, use Docker. AWS is used for
consistent results - it's easy to verify that the same hardware was
used. Docker is easier to use, and more similar to how people normally
deploy Discourse in production.

You *could* also configure it yourself as a local application. This is
really quite difficult because Discourse's dependencies are extensive.

## Running with Docker

For a rundown of how you'd normally use Docker-based Discourse, you
can [see their
documentation.](https://github.com/discourse/discourse/blob/master/docs/INSTALL-cloud.md)
You'll do *nearly* the same thing.

Instead of running discourse-setup, just copy docker/app.yml into your
discourse_docker checkout's "countainer" directory. Then, when you set
up Discourse, you'll get an image that contains the Rails Ruby Bench
benchmark. After that, you'll run the benchmark against Discourse
inside the container. Here's what that might look like as a series of
steps:

~~~
# Install Docker, if you don't have it
wget -qO- https://get.docker.com/ | sh

# Clone discourse_docker into a location of your choice - we'll use ~/src/discourse for the examples
mkdir ~/src/discourse_docker
git clone https://github.com/discourse/discourse_docker.git ~/src/discourse_docker
cd ~/src/discourse_docker

# You can ignore email and domain setup if you're just using Discourse for RRB

# Copy app.yml into place instead of running discourse-setup
cp ~/src/rails_ruby_bench/docker/app.yml ~/src/discourse_docker/containers/

# Run the launcher
sudo -s  # Needed by Docker
# The prereqs check fails on standard MacOS Docker, which returns an incorrect root dir
./launcher rebuild app --skip-prereqs

# Don't worry about checking in the browser or making an admin account

# -- End of Steps from Discourse --

# Run the benchmark - you can add options after ./start.rb
./launcher run "cd ~/src/rails_ruby_bench && ./start.rb" --skip-prereqs
~~~

## Building It Yourself with Docker

The "docker" subdirectory contains a lot of important bits - the
Dockerfile, the build script (build.sh) and so on. If you need to
modify them to change configuration, you'll want to build with a
different name/tag.

You can change build.sh to use a different name, or just do the same
thing it does and build from the Dockerfile on the command line.

You'll also need to change app.yml to use your new base_image name.

## Command-Line Options

Start.rb supports a number of options:

    -r NUMBER      Set the random seed
    -i NUMBER      Number of total iterations (default: 1500)
    -n NUMBER      Number of load threads in the user simulator
    -s NUMBER      Number of start/stop iterations, measuring time to first successful request
    -w NUMBER      Number of warmup HTTP requests before timing
    -p NUMBER      Port number for Puma server (default: 4567)
    -o DIR         Directory for JSON output
    -t NUMBER      Threads per Puma server
    -c NUMBER      Number of cluster processes for Puma

## Running the Benchmark with Packer

First, make sure Packer is installed and that you have AWS set up.

Then change into the "packer" subdirectory. Run "packer ami.json".

That will build your AMI. You can start an instance from that AMI as
normal. Once you've ssh'd into the image, change to the
~ubuntu/rails_ruby_bench subdirectory and run ./start.rb.

Be careful - by default, the instance will run some iterations of the
benchmark on boot-up, just to have some data available. Make sure the
initial benchmark run has completed before your start your own. You
can check with "ps aux | grep ruby" and make sure no processes are
currently running.

### Customizing the Benchmark with Packer

The benchmark uses the Ruby and Discourse versions found in
setup.json. You can customize them there, then re-run setup.rb.
You may need to clear the cloned versions in the work directory
first.

## Definitive Benchmark Numbers and AWS

The definitive version of the benchmark uses an AWS m4.2xlarge
instance and an AMI. This has 8 vCPUs (4 virtual cores) as discussed
in the design documentation, and doesn't have an excessive amount of
memory or I/O priority. It's a realistic hosting choice at roughly
$270/month if running continuously. Your benchmark should run in well
under an hour and cost about $0.40 (40 cents) in USD.

To create your own AMI, see packer/README.md in this Git repo.

With your AMI (or using a public AMI), you can launch an instance as
normal for AWS. Here's an example command line:

    aws ec2 run-instances --image-id ami-f678218d --count 1 --instance-type m4.2xlarge --key-name MyKeyPair --placement Tenancy=dedicated

Replace "MyKeyPair" with the name of your own AWS keypair. You can, of course, replace the AMI ID with the current latest public AMI, or one you built.

The current publicly available AMIs are:

    ami-554a4543 for Discourse v1.5 and Ruby 2.0.0 through 2.3.4

    ami-f678218d for Discourse v1.8 and Ruby 2.3.4 and 2.4.1

## Debugging with the AMI

Example command lines:

    aws ec2 run-instances --count 1 --instance-type m4.2xlarge --key-name my-ssh-key-name --placement Tenancy=dedicated --image-id ami-f678218d
    ssh -i ~/.ssh/my-ssh-key-name.pem ubuntu@ec2-34-228-227-234.compute-1.amazonaws.com
    cd rails_ruby_bench
    ./in_each_ruby.rb "for i in {1..20}; do ./start.rb -i 3000 -w 100 -s 0; done"

You'll need to find the public DNS name of the VM you created
somehow. I normally use the EC2 dashboard. Similarly, you should use
an SSH key name that exists in your AWS account. The parameters above
are for an m4.2xlarge dedicated instance. That's a bit expensive, but
will also give you reproducible results that you can compare directly
with mine. If you use a much smaller instance, you'll want to reduce
the number of load-testing threads and Puma processes and threads.

I normally copy the JSON files back to my own machine, something like:

> scp -i ~/.ssh/my-ssh-key-name.pem ubuntu@ec2-34-228-227-234.compute-1.amazonaws.com:~/rails_ruby_bench/*.json ./my_local_directory

## Debugging and AWS

By default, the Rails benchmark is git-cloned under
~ubuntu/rails\_ruby\_bench, and Discourse is cloned under the work
subdirectory of that repository. The built Rubies are mounted using
rvm for the benchmark. You can see them with "rvm list". If you want
to change anything when starting your own instance, those are great
places to begin.

By default, the image won't update or rebuild Ruby or Discourse, nor
update the Rails Ruby benchmark on boot. It will use the versions of
all of those things that were current when the AMI was built. But you
can modify your own image later however you like.

If you'd like to change the behavior of the AWS image, you can use AWS
user data to run a script on boot. See
"http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html".

You can also just log in and make whatever changes you want, of course.

## Decisions and Intent

* Configurable Ruby, Rails and Discourse versions. This makes it easy
  to test a particular optimization or fix to any of Ruby, Rails or
  Discourse. To test other fixes to most software, the gem version in
  Rails can be updated at a different URL. This doesn't make it as
  easy to test fixes to system libraries or programs (e.g. libxml,
  postgres) which are less likely to be patched just because of Ruby
  performance.

* Use Discourse code because it's a real Rails application, used in
  production, with a reasonably stable REST API. This tests many code
  paths in realistic proportions.

* Use random seed for client because it provides a reasonable balance
  between unpredictability and stability. Note that no multithreaded
  or multiprocess benchmark using a host (real or virtual) is going to
  be fully reproducible or stable. But the random seed for client
  requests provides a baseline of reproducibility, within the limits
  of a benchmark that isn't extremely artificial.

* Test with multiple requests at once because better Ruby concurrency
  is an explicit goal of Ruby 3x3. The first question most people ask
  of any Ruby optimization is "how much will it improve my Rails
  performance?" Concurrency is key to answering this question.

* Use Puma because we want multithreaded operation. Multithreaded
  means Puma or Thin or commercial Passenger. Puma is more commonly
  used as a high-performance multithreaded Ruby application server at
  this point.

* Use AWS because it's common, it's an industry standard and it's easy
  to test. Also, nearly all other cloud offerings are measured against
  AWS. AWS numbers will be treated as meaningful on their face.

* Use postgres on same machine: on same machine to avoid AWS time in
  benchmarking, require Postgres because Discourse does and can't be
  easily changed. (https://meta.discourse.org/t/why-not-support-mysql/2568/2)

* Use Sidekiq on same machine: on same machine to avoid AWS time in
  benchmarking, use Sidekiq because it's fast, simple, in Ruby and not
  trivial to change.

* Don't use Discourse's existing benchmark script because it simply
  runs a (very) small set of URLs, and only tests one URL at once.
