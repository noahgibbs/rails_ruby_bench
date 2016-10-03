class BenchmarkController < ApplicationController
  def start
    render :text => "OK", :status => 200
  end

  def simple_request
    render :text => "Hello, World."
  end
end
