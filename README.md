This is an initial attempt at a Rails benchmark for Ruby. The intent
is that it will be reviewed by members of the Ruby core team and
others and eventually be the basis for an optcarrot-style Ruby
benchmark for Rails applications.

## Running the Benchmark Locally

First, run setup.rb. This will clone your chosen Ruby and Discourse
versions. Then run "RAILS\_ENV=profile ./seed\_db\_data.rb". to create
account data in your database. Then run start.rb to run the server and
the benchmark.

## Customizing the Benchmark

The benchmark uses the Ruby and Discourse versions found in
setup.json. You can customize them there, then re-run setup.rb.
You may need to clear the cloned versions in the work directory
first.

## Definitive Benchmark Numbers

The definitive version of the benchmark uses an AWS (TBD) instance and
an AMI.

(To be written: how to create the AMI and get definitive numbers for
the chosen 8-vCPU AWS instance.)

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
