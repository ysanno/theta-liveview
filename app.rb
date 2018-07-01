require 'sinatra'
require 'net/http'
require 'json'
require 'pp'

Thread.new do
  http = Net::HTTP.new('192.168.1.1', 80)
  pp JSON.parse(http.get('/osc/info').body)

  pp res = JSON.parse(http.post('/osc/commands/execute', {name: 'camera.startSession'}.to_json).body)

  if res['state'] == 'done'
    sessionId = res['results']['sessionId']
    params = {name: 'camera.setOptions', parameters: {sessionId: sessionId, options: {clientVersion: 2}}}.to_json
    pp JSON.parse(http.post('/osc/commands/execute', params).body)
  end

  data = ''
  http.request_post('/osc/commands/execute', {name: 'camera.getLivePreview'}.to_json, {'Content-Type' => 'application/json'}) do |res|
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
      image.sub!(/^Content-Type:.*$/, '')
      image.sub!(/^Content-Length:.*$/, '')
      image.gsub!(/\A[\r\n]*/m, '')
      image.gsub!(/[\r\n]*\Z/m, '')
      $image = image
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
