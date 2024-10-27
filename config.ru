require 'rackup'
require './ractor_server'
require './app'
require 'rack/runtime'

Rackup::Handler.register 'ractor_server', RactorServer

use Rack::Runtime
run App.new

