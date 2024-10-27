# frozen_string_literal: true

class App
  def call(env)
    response_headers = { 'Content-Type' => 'text/plain' }
    response_headers.transform_keys!(&:downcase)
    [
      200,
      response_headers,
      ['Hello, World!']
    ]
  end
end

