#!/bin/bash

# Start the Rails server and measure time to first request.

# Start the server
cd MarkApp
RAILS_ENV=production rails server &
cd ..

i = "0"

while [ $i -lt 100 ]
do
  curl http://localhost:3000/start_benchmark
  sleep 0.1

  i=$[$i+1]
done

# Kill the server
ps | grep MarkApp | grep -v grep | cut -f 1 -d " " | xargs kill -9
