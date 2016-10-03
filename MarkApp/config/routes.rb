Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root "benchmark#root"
  get "/benchmark/start" => "benchmark#start"
  get "/benchmark/simple_request" => "benchmark_simple_request"
end
