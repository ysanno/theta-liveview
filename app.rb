require 'sinatra'
require 'net/http'
require 'json'
require 'pp'
require 'net/http/digest_auth'

HOSTNAME = ENV['THETA_HOSTNAME'] || '192.168.1.1'
USERNAME = ENV['THETA_USERNAME'] # for client mode
PASSWORD = ENV['THETA_PASSWORD'] # for client mode

Thread.new do
  while true do
    http = Net::HTTP.new(HOSTNAME, 80)
    res = http.get('/osc/info')

    auth = nil
    if res.code == '401'
      uri = URI.parse("http://#{HOSTNAME}/osc/info")
      uri.user = USERNAME
      uri.password = PASSWORD
      www_authenticate = res['www-authenticate']
      digest_auth = Net::HTTP::DigestAuth.new
      auth = digest_auth.auth_header(uri, www_authenticate, 'GET')
      res = http.get(uri.path, {Authorization: auth})

      uri.path = '/osc/commands/execute'
      auth = digest_auth.auth_header(uri, www_authenticate, 'POST')
    end
    pp JSON.parse(res.body)

    pp res = JSON.parse(http.post('/osc/commands/execute', {name: 'camera.startSession'}.to_json, {Authorization: auth}).body)

    if res['state'] == 'done'
      sessionId = res['results']['sessionId']
      params = {name: 'camera.setOptions', parameters: {sessionId: sessionId, options: {clientVersion: 2}}}.to_json
      pp JSON.parse(http.post('/osc/commands/execute', params).body)
    end

    data = ''
    http.request_post('/osc/commands/execute', {name: 'camera.getLivePreview'}.to_json, {'Content-Type' => 'application/json', Authorization: auth}) do |res|
      next if res.code != '200'
      puts res['content-type']
      res.read_body do |body|
        data << body
        image = data.split('---osclivepreview---')
        next if image.length < 2
        data = image[image.length - 1]
        next if image[0].length == 0
        image = image[0]
        puts image.lines[2]
        image.sub!(/^Content-(T|t)ype:.*$/, '')
        image.sub!(/^Content-Length:.*$/, '')
        image.gsub!(/\A[\r\n]*/m, '')
        image.gsub!(/[\r\n]*\Z/m, '')
        $image = image
      end
    end
  end
end

configure do
  mime_type :image, 'image/jpeg'
end

get '/' do
  redirect to('/index.html')
end

get '/image.jpg' do
  content_type :image
  $image
end
