Rails StartMark and RequestMark

Decisions:

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
  runs a (very) small set of URLs, consecutively, in a single thread.

* Don't use Discourse's data for that benchmark because it includes
  few data items and no testing of concurrent access.


URLs to figure out:

* home page
* add post(s)
* view posts
* view topic(s)
* delete post(s)

TODO:

* Put together scripts that can run across multiple machines for request benchmark
* Allow database on additional host




Assumptions:

* Multithreaded parallel benchmark using Puma

* Test startup time

* Test parallel requests to DB and without DB access

* Little calculation or GC in requests. We have other benchmarks for these.

* Maybe show off Guilds somehow, in a way that requires or showcases multiple bits of Ruby calculation at once?

Issues:

* ensure minimum latency between Rails server start and first request - signal somehow? With a touched file?

Test:

* For SQLite, do complex SQL queries happen in-process? Are they profiled as counting against the Rails process? Would be much better to test with Rails waiting for IO, not calculating.

For final benchmark:

* Run DB on a different machine? Use Postgres or MySQL?
