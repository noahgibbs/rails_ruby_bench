# NAME: rails_ruby_bench/discourse
# VERSION: release
FROM discourse/base:2.0.20180907

#LABEL maintainer="Noah Gibbs"

ENV RRB_GIT_URL https://github.com/noahgibbs/rails_ruby_bench.git

RUN echo 2.0.`date +%Y%m%d` > /RRB_VERSION

RUN chown discourse:discourse /var

# Additional packages to compile Rubies
RUN apt-get install -y bison autoconf build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm-dev

# Additional SQLite3 package, mostly for Mailcatcher gem
RUN apt-get install -y libsqlite3-dev

# Clone Rails Ruby Bench
RUN sudo -H -u discourse git clone ${RRB_GIT_URL} /var/rails_ruby_bench

# Install RRB gems into system Ruby
RUN cd /var/rails_ruby_bench && bundle

ADD install_rbenv.sh /tmp/install_rbenv.sh
RUN chmod +x /tmp/install_rbenv.sh && sudo -H -u discourse /tmp/install_rbenv.sh

# Copy in Ruby settings, which may be modified from checked-in version
ADD benchmark_software.json /tmp/benchmark_software.json

ADD build_benchmark_software.rb /tmp/build_benchmark_software.rb
RUN chmod +x /tmp/build_benchmark_software.rb && sudo -H -u discourse /tmp/build_benchmark_software.rb

ADD benchmark_discourse_setup.rb /tmp/benchmark_discourse_setup.rb
RUN chmod +x /tmp/benchmark_discourse_setup.rb && sudo -H -u discourse /tmp/benchmark_discourse_setup.rb

ADD test_benchmark_run.rb /tmp/test_benchmark_run.rb
RUN chmod +x /tmp/test_benchmark_run.rb && sudo -H -u discourse /tmp/test_benchmark_run.rb
