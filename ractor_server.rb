# frozen_string_literal: true
# shareable_constant_value: experimental_everything

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

          env = {
            'REQUEST_METHOD' => 'GET',
            'SCRIPT_NAME' => '',
            'PATH_INFO' => '/',
            'QUERY_STRING' => '',
            'SERVER_NAME' => server.options[:Host].to_s,
            'SERVER_PORT' => server.options[:Port].to_s,
            'SERVER_PROTOCOL' => 'HTTP/1.1',
            'rack.url_scheme' => 'http',
            'rack.errors' => $stderr,
          }

          server.app.call(env) => status, response_headers, body
          conn.puts "HTTP/1.1 #{status} OK"
          response_headers.each { |k, v| conn.puts "#{k}: #{v}" }
          conn.puts
          body.each { |line| conn.puts line }
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

  private def write_pid
    File.open('tmp/pids/ractor_server.pid', 'w') { |f| f.write(Process.pid) }
  end
end

