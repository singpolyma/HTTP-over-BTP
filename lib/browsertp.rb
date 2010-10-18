# This is Rack middleware
# It parses the body of an incoming requst as the *actual* HTTP request
#
# It is useful in cases where you have a client that speaks some subset of HTTP
# but not everything (like XMLHTTPRequest)
#
# If you construct it with a query parameter, then it will only be active when
# that key is part of the query string or form-encoded POST data

class BrowserTP
  def initialize(app, query=nil)
    @app = app
    @query = query
  end

  def parse_http(string)
    http = {:headers => {}}

    input = string.split(/\r?\n/)
    http[:request_method], http[:path_info], http[:server_protocol] = input.shift.split(/\s+/, 3)
    http[:path_info] = http[:path_info].split('?', 2)[0].to_s
    http[:query_string] = http[:path_info].split('?', 2)[1].to_s

    last_header = nil
    line = ''
    while true
      line = input.shift
      break if line == '' || !line
      if line[0,1] =~ /\s/
        http[:headers][last_header] << line
      else
        line = line.split(/:\s*/, 2)
        last_header = line.first
        http[:headers][line[0]] = line[1]
      end
    end

    http[:body] = input.join("\r\n")

    http
  end

  def call(env)
    if !@query || Rack::Request.new(env).params.keys.include?(@query)
      http = parse_http(env['rack.input'].read)
      env['REQUEST_METHOD'] = http[:request_method]
      env['PATH_INFO'] = http[:path_info]
      env['QUERY_STRING'] = http[:query_string]
      env['SERVER_PROTOCOL'] = http[:server_protocol]

      http[:headers].each do |header, value|
        env['HTTP_' + header.upcase.gsub(/-/, '_')] = value
      end

      env['rack.input'] = StringIO.new(http[:body])
    end
    @app.call(env)
  end
end
