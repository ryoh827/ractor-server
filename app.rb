class App
  def call(env)
    if env['PATH_INFO'] == '/'
      [200, {}, ['It works!']]
    else
      [404, {}, ['Not Found']]
    end
  end
end

