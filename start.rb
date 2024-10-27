require './app'
require './ractor_server'

RactorServer.new(App.new, {"Host": "localhost", "Port": 9292}).start

