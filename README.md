Rails StartMark and RequestMark

Assumptions:

* Multithreaded parallel benchmark using Puma

* Test startup time

* Test parallel requests to DB and without DB access

* Little calculation or GC in requests. We have other benchmarks for these.

* Maybe show off Guilds somehow, in a way that requires or showcases multiple bits of Ruby calculation at once?

Issues:

* ensure minimum latency between Rails server start and first request - signal somehow? With a touched file or something?
