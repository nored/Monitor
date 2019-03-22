require "rubygems"
require "sinatra"

Bundler.require

require File.expand_path '../monitor.rb', __FILE__

run App
