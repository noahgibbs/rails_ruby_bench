Rails StartMark and RequestMark

Issues:

* ensure minimum latency between Rails server start and first request - signal somehow? With a touched file or something?

* requests - parallel or serial? If parallel, that suggests using a parallel app server, not WEBRick. Maybe flavors by app server? Puma vs Unicorn or something?

* Probably not a lot of calculation in requests, and minimal GC. We have other benchmarks for those things. But maybe some kind of active something to show off Guilds? Can't just be I/O-bound or waiting on an event if we want Guilded Ruby to be better.


