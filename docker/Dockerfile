# NAME: rails_ruby_bench/discourse
# VERSION: release
FROM discourse/base:2.0.20180907

#LABEL maintainer="Noah Gibbs"

ENV RRB_GIT_URL https://github.com/noahgibbs/rails_ruby_bench.git

RUN echo 2.0.`date +%Y%m%d` > /RRB_VERSION

RUN chown discourse:discourse /var

# Clone Rails Ruby Bench
RUN sudo -H -u discourse git clone ${RRB_GIT_URL} /var/rails_ruby_bench
RUN cd /var/rails_ruby_bench && sudo -H -u discourse bundle install --deployment

# Copy in Ruby settings, which may be modified from checked-in version
ADD benchmark_software.json /tmp/benchmark_software.json

ADD build_benchmark_software.rb /tmp/build_benchmark_software.rb
RUN sudo -H -u discourse /tmp/build_benchmark_software.rb

