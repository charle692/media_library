require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'erb'
require './media_library'

set :environment, :development
set :run, false
set :raise_errors, true

run Sinatra::Application
