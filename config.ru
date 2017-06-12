require_relative 'config/bootstrap.rb'
require 'routemaster/application'
require 'core_ext/puma_util'

run Routemaster::Application
STDERR.puts "config.ru finishing"
