#!/usr/bin/env rackup
# encoding: utf-8
#\ -E deployment

# This is a simple tunnel proxy using the BrowserTP middleware
# Any request sent to this will assume the body is HTTP, parse it,
# and forward it on to the host in the Host header.
#
# The response body will be the raw response from the remote server.
#
# A production deployment of this will probably want to hard-code or
# limit the hosts/ports that can be used

require 'socket'

$: << File.dirname(__FILE__) + '/lib'
require 'browsertp'

use BrowserTP
use Rack::Reloader
use Rack::ContentLength

run (lambda { |env|
  unless env['HTTP_HOST'].to_s =~ /^\s+$/
    headers = env.keys.select {|key| key =~ /^HTTP_/ }.map do |k|
      next if k == 'HTTP_SERVER'
      header = k.sub(/^HTTP_/, '').gsub(/_/, '-')
      "#{header}: #{env[k]}"
    end.join("\r\n")

    # XXX: currently only supports outgoing connections to port 80
    socket = TCPSocket.new(env['HTTP_HOST'], 80)

    socket.print("#{env['REQUEST_METHOD']} #{env['PATH_INFO']}?#{env['QUERY_STRING']} #{env['SERVER_PROTOCOL']}\r\n")
    socket.print(headers)
    socket.print("\r\n\r\n")
    socket.print(env['rack.input'].read)
    socket.print("\r\n")

    response = ''
    begin
      timeout(10) {
        while line = socket.recv(100)
          response << line
          break if line.length < 100
        end
      }
    rescue Exception
      # Timed out.  Oh well
    end

    socket.close

    [200, {'Content-Type' => 'text/plain'}, response]
  else
    [200, {'Content-Type' => 'text/plain'}, 'Error: no Host header sent.']
  end
})
