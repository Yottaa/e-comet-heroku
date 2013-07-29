require 'bundler'
require 'net/http'
require 'net/https'
require 'uri'
require 'json'

Bundler.require

STDOUT.sync = true

# utility class for yottaa custom header
class CaseSensitiveString < String
  def downcase
    self
  end

  def capitalize
    self
  end
end

STDOUT.puts "Retrieve list of sites you have registerd with Yottaa."
uri = URI.parse("https://api.yottaa.com/sites/" + ENV['YOTTAA_SITE_ID'])

https = Net::HTTP.new(uri.host, uri.port)
https.use_ssl = true
https.verify_mode = OpenSSL::SSL::VERIFY_NONE

custom_header_key = CaseSensitiveString.new("YOTTAA-API-KEY")
req = Net::HTTP::Get.new(uri, {custom_header_key =>ENV['YOTTAA_API_KEY']})
req.set_form_data({"user_id" => ENV['YOTTAA_USER_ID']})
https.set_debug_output($stdout)

res = https.request(req)

result = JSON.parse(res.body)

if !result.has_key? 'error'
  STDOUT.puts result.to_json
else
  STDOUT.puts result.to_json
end