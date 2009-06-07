#!/usr/local/ruby187/bin/ruby
require 'rubygems'

load 'start.rb'

set :run, false

Rack::Handler::CGI.run Sinatra::Application
