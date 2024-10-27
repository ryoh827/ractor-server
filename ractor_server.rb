# frozen_string_literal: true

require 'socket'

class RactorServer
  PORT = ENV.fetch('PORT', 9292)
  HOST = ENV.fetch('HOST', '127.0.0.1').freeze
  NATIVE_THREAD_NUM = ENV.fetch('RUBY_MAX_CPU', 2).to_i
  WORKER_PER_PROCESS_COUNT = ENV.fetch('WORKER_PER_PROCESS_COUNT', 4).to_i
  WORKERS_COUNT = NATIVE_THREAD_NUM * WORKER_PER_PROCESS_COUNT

  attr_accessor :app, :options

  def self.run(app, **options)
    self.new(app, options).start
  end

  def initialize(app, options)
    self.app = app
    self.options = options
  end

  def start
    puts "Ractor Server is running on #{HOST}:#{PORT}"

    write_pid

    queue = Ractor.new do
      loop do
        conn = Ractor.receive
        Ractor.yield(conn, move: true)
      end
    end

    WORKERS_COUNT.times do
      Ractor.new(queue, self) do |queue, server|
        loop do
          conn = queue.take

          path = '/'

          env = { 
            Rack::REQUEST_METHOD => 'GET',
            Rack::SCRIPT_NAME => '',
            Rack::PATH_INFO => path,
            Rack::SERVER_NAME => server.options[:Host],
            Rack::RACK_INPUT => conn,
            Rack::RACK_ERRORS => $stderr,
            Rack::QUERY_STRING => '',
            Rack::REQUEST_PATH => path,
            Rack::RACK_URL_SCHEME => 'http',
            Rack::SERVER_PROTOCOL => 'HTTP/1.1'
          }

          # server.app.call(env) # cant use this because of the ractor
          conn.puts "HTTP/1.1 200 OK"
          conn.puts "Content-Type: text/html"
          conn.puts "Content-Length: 11"
          conn.puts ""
          conn.puts "Hello World"
        ensure
          conn&.close
        end
      end
    end

    listener = Ractor.new(queue) do |que|
      socket = TCPServer.new(HOST, PORT)
      loop do
        conn, _ = socket.accept
        que.send(conn, move: true)
      end
    end

    Ractor.select(listener)
  end

  private

  def write_pid
    File.open('tmp/pids/ractor_server.pid', 'w') { |f| f.write(Process.pid) }
  end
end

