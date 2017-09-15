This is an initial attempt at a Rails benchmark for Ruby. The intent
is that it will be reviewed by members of the Ruby core team and
others and eventually be the basis for an optcarrot-style Ruby
benchmark for Rails applications.

This benchmark steals some code from Discourse
(e.g. user\_simulator.rb, seed\_db\_data.rb), so it's licensed GPLv2.

## Running the Benchmark Locally (Easy Version)

Make sure to install the gems:

    $ bundle

Then, get Discourse set up:

    $ cd work/discourse
    $ bundle
    $ rake db:create db:migrate  # If necessary, db:drop first

Then, run the database seeding script:

    $ cd ../.. # Back to root directory rather than work/discourse
    $ ruby seed_db_data.rb  # And wait awhile - it's slow

Now you can run the benchmark:

    $ ./start.rb

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

## Running the Benchmark Locally (Complete Version)

First, run the setup from the root of this repo:

```bash
Switch to a 2.3.4 or 2.4.1 Ruby
$ ruby packer/setup.rb --local
```

You will also need to install Discourse dependencies.
There's a script in the Discourse directory to do it on OS X under
work/discourse/script/osx_dev.
Refer to [this page](https://github.com/discourse/discourse/blob/v1.8.0.beta13/docs/DEVELOPER-ADVANCED.md#preparing-a-fresh-ubuntu-install) for Linux.

Rerun the setup until it succeeds.

Then run start.rb to run the server and the benchmark.

## Customizing the Benchmark

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

## Debugging and AWS

If you'd like to change the behavior of the AWS image, you can use AWS
user data to run a script on boot. See
"http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html".

By default, the Rails benchmark is git-cloned under
~ubuntu/rails\_ruby\_bench, and Ruby and Discourse are cloned under
the work subdirectory of that repository. The built Ruby is installed
into /usr/local/benchmark/ruby and mounted using rvm for the
benchmark. If you want to change any of this when starting your own
instance, those are great places to begin.

By default, the image won't update or rebuild Ruby or Discourse, nor
update the Rails Ruby benchmark on boot. That is, by default it will
use the versions of all of those things that were current when the AMI
was built. But you can modify your own image later however you like.

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
