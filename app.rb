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

class App < Sinatra::Base
  use Rack::Session::Cookie, secret: ENV['SSO_SALT']

  #YOTTAA_API_URL_ROOT = "https://api-dev.yottaa.com"
  YOTTAA_API_URL_ROOT = "https://api.yottaa.com"

  #YOTTAA_CUSTOM_HEADER_PARTNER = {CaseSensitiveString.new("YOTTAA-API-KEY") =>'39e8b9b0b1000130d279123138106137'}
  #YOTTAA_API_URL_PARTNER = YOTTAA_API_URL_ROOT + "/partners/51b0cd1bebe2bb3069000f0d"

  YOTTAA_CUSTOM_HEADER_PARTNER = {CaseSensitiveString.new("YOTTAA-API-KEY") =>'455df7500258012f663b12313d145ceb'}
  YOTTAA_API_URL_PARTNER = YOTTAA_API_URL_ROOT + "/partners/4d34f75b74b1553ba500007f"

  helpers do
    def protected!
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials &&
      @auth.credentials == [ENV['HEROKU_USERNAME'], ENV['HEROKU_PASSWORD']]
    end

    def show_request
      body = request.body.read
      unless body.empty?
        STDOUT.puts "request body:"
        STDOUT.puts(@json_body = JSON.parse(body))
      end
      unless params.empty?
        STDOUT.puts "params: #{params.inspect}"
      end
    end

    def json_body
      @json_body || (body = request.body.read && JSON.parse(body))
    end

    def get_resource
      # locate Yottaa account by site id
      site_id = params[:id]
      user_id = ENV["YOTTAA_USER_ID"]
      if ! user_id.nil?
        uri = URI.parse(YOTTAA_API_URL_PARTNER + "/accounts/" + user_id + "/sites/" + site_id)
        https = https_connection(uri)
        req = Net::HTTP::Get.new(uri, YOTTAA_CUSTOM_HEADER_PARTNER)
        https.set_debug_output($stdout)

        res = https.request(req)
        result = JSON.parse(res.body)
        if result.has_key? 'id'
          return result
        else
          halt 404, 'resource not found'
        end
      else
        halt 404, 'resource not found'
      end
    end

    def https_connection (uri)
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_NONE
      return https
    end
  end

  # sso landing page
  get "/" do
    #hack- halt 403, 'not logged in' unless session[:heroku_sso]
    #response.set_cookie('heroku-nav-data', value: session[:heroku_sso])
    @resource = session[:resource]
    #hack- @email    = session[:email]
    STDOUT.puts session[:resource].to_json
    @email    = 'yong.qu@yottaa.com'
    @status = session[:resource]['optimizer']

    @message = session[:message]
    @error = session[:error]
    session[:message] = ''
    session[:error] = ''
    haml :index
  end

  def sso
    STDOUT.puts ENV['SSO_SALT']
    STDOUT.puts params[:id]
    STDOUT.puts params[:timestamp]
    timenow = (Time.now).to_i.to_s
    #hack- pre_token = params[:id] + ':' + ENV['SSO_SALT'] + ':' + params[:timestamp]
    pre_token = params[:id] + ':' + ENV['SSO_SALT'] + ':' + timenow
    token = Digest::SHA1.hexdigest(pre_token).to_s
    #hack- halt 403 if token != params[:token]
    #hack- halt 403 if params[:timestamp].to_i < (Time.now - 2*60).to_i

    halt 404 unless session[:resource]   = get_resource

    response.set_cookie('heroku-nav-data', value: params['nav-data'])
    session[:heroku_sso] = params['nav-data']
    session[:email]      = params[:email]

    redirect '/'
  end

  # sso sign in
  get "/heroku/resources/:id" do
    show_request
    sso
  end

  post '/sso/login' do
    puts params.inspect
    sso
  end

  # provision
  post '/heroku/resources' do
    show_request
    protected!

    # Try to see if any option is provided by command line parameters
    options = json_body.fetch('options', {})
    first_name = options.fetch('first_name','')
    last_name = options.fetch('last_name','')
    phone = options.fetch('phone','')
    email = options.fetch('email', json_body.fetch('heroku_id'))
    site = options.fetch('site','')

    site_id = options.fetch('site_id','')
    user_id = options.fetch('user_id','')
    api_key = options.fetch('api_key','')

    plan = json_body.fetch("plan", "free")

    # Check if both email and site are provided
    if !email.empty? && !site.empty?
      STDOUT.puts "Creating a new Yottaa account"

      uri = URI.parse(YOTTAA_API_URL_PARTNER + "/accounts")
      https = https_connection(uri)
      req = Net::HTTP::Post.new(uri, YOTTAA_CUSTOM_HEADER_PARTNER)
      req.set_form_data({"first_name" => first_name, "last_name" => last_name, "email" => email, "site" => site, "phone" => phone, "plan" => plan})
      https.set_debug_output($stdout)

      res = https.request(req)
      result = JSON.parse(res.body)

      if !result.has_key? 'error'
        status 201
        resource_id = result["site_id"]
        body({
                 :id => resource_id,
                 :config => {"YOTTAA_SITE_ID" => result["site_id"], "YOTTAA_USER_ID" => result["user_id"], "YOTTAA_API_KEY" => result["api_key"]},
                 :message => 'Dear ' + first_name + ' ' + last_name +', your Yottaa account is now provisioned!'
             }.to_json)
=begin
        # Try to figure out the domain name of the app which just installed this add-on
        uri = URI.parse("https://api.heroku.com/vendor/apps/" + resource_id)
        https = https_connection(uri)
        HEROKU_CUSTOM_HEADER = {"Accept" =>'application/vnd.heroku+json; version=3'}
        req = Net::HTTP::Get.new(uri, HEROKU_CUSTOM_HEADER)
        req.basic_auth "yong.qu@yottaa.com", "y0ttaa1234"
        https.set_debug_output($stdout)
        res = https.request(req)
        result = JSON.parse(res.body)
        domain = result["domains"][0]
        # Now update Yottaa account for the actual domain name???
=end
      else
        status 422
        body(result['error'].to_json)
      end
    else
      if !site_id.empty? && !user_id.empty? && !api_key.empty?
        # validate the combo
        uri = URI.parse(YOTTAA_API_URL_ROOT + "/sites/" + site_id)
        https = https_connection(uri)
        req = Net::HTTP::Get.new(uri, {CaseSensitiveString.new("YOTTAA-API-KEY") =>api_key})
        req.set_form_data({"user_id" => user_id})
        https.set_debug_output($stdout)

        res = https.request(req)
        result = JSON.parse(res.body)
        if !result.has_key? 'error'
          body({
                   :id => site_id,
                   :config => {"YOTTAA_SITE_ID" => site_id, "YOTTAA_USER_ID" => user_id, "YOTTAA_API_KEY" => api_key},
                   :message => 'Dear customer' +', your Yottaa account is now provisioned!'
               }.to_json)
         end
      else
        status 422
        body({:error => 'Valid email and site url must be provided.'}.to_json)
      end
    end
  end

  # deprovision
  delete '/heroku/resources/:id' do
    show_request
    protected!

    resource = get_resource
    user_id = ENV["YOTTAA_USER_ID"]
    site_id = resource['id']

    # try to delete site
    STDOUT.puts "Deleting Yottaa site with id " + site_id
    uri = URI.parse(YOTTAA_API_URL_PARTNER + "/accounts/" + user_id + "/sites/" +site_id)
    https = https_connection(uri)
    req = Net::HTTP::Delete.new(uri, YOTTAA_CUSTOM_HEADER_PARTNER)
    https.set_debug_output($stdout)
    res = https.request(req)
    result = JSON.parse(res.body)

    if !result.has_key? 'error'
      "ok"
    else
      body(result["error"].to_json)
    end

  end

  # plan change
  put '/heroku/resources/:id' do
    show_request
    protected!
    resource = get_resource
    plan = json_body['plan']
    {}.to_json
  end

  post "/bypass" do
    uri = URI.parse(YOTTAA_API_URL_ROOT + "/optimizers/" + ENV["YOTTAA_SITE_ID"] +"/bypass")
    https = https_connection(uri)
    req = Net::HTTP::Put.new(uri, {CaseSensitiveString.new("YOTTAA-API-KEY") =>ENV["YOTTAA_API_KEY"]})
    req.set_form_data({"user_id" => ENV["YOTTAA_USER_ID"]})
    https.set_debug_output($stdout)
    res = https.request(req)
    result = JSON.parse(res.body)

    if !result.has_key? 'error'
      session[:message] = 'Your Yottaa optimizer has been changed to bypass mode.'
    else
      session[:error] = 'Error received from changing Yottaa optimizer to bypass mode:' + result["error"].to_json
    end
    redirect '/heroku/resources/' + ENV["YOTTAA_SITE_ID"]
  end

  post "/transparent" do
    uri = URI.parse(YOTTAA_API_URL_ROOT + "/optimizers/" + ENV["YOTTAA_SITE_ID"] +"/transparent")
    https = https_connection(uri)
    req = Net::HTTP::Put.new(uri, {CaseSensitiveString.new("YOTTAA-API-KEY") =>ENV["YOTTAA_API_KEY"]})
    req.set_form_data({"user_id" => ENV["YOTTAA_USER_ID"]})
    https.set_debug_output($stdout)
    res = https.request(req)
    result = JSON.parse(res.body)

    if !result.has_key? 'error'
      session[:message] = 'Your Yottaa optimizer has been changed to transparent proxy mode.'
    else
      session[:error] = 'Error received from changing Yottaa optimizer to transparent proxy mode:' + result["error"].to_json
    end
    redirect '/heroku/resources/' + ENV["YOTTAA_SITE_ID"]
  end

  post "/resume" do
    uri = URI.parse(YOTTAA_API_URL_ROOT + "/optimizers/" + ENV["YOTTAA_SITE_ID"] +"/resume")
    https = https_connection(uri)
    req = Net::HTTP::Put.new(uri, {CaseSensitiveString.new("YOTTAA-API-KEY") =>ENV["YOTTAA_API_KEY"]})
    req.set_form_data({"user_id" => ENV["YOTTAA_USER_ID"]})
    https.set_debug_output($stdout)
    res = https.request(req)
    result = JSON.parse(res.body)

    if !result.has_key? 'error'
      session[:message] = 'Your Yottaa optimizer has been resumed.'
    else
      session[:error] = 'Error received from resuming Yottaa optimizer:' + result["error"].to_json
    end
    redirect '/heroku/resources/' + ENV["YOTTAA_SITE_ID"]
  end

  post "/flush" do
    uri = URI.parse(YOTTAA_API_URL_ROOT + "/sites/" + ENV["YOTTAA_SITE_ID"] +"/flush_cache")
    https = https_connection(uri)
    req = Net::HTTP::Put.new(uri, {CaseSensitiveString.new("YOTTAA-API-KEY") =>ENV["YOTTAA_API_KEY"]})
    req.set_form_data({"user_id" => ENV["YOTTAA_USER_ID"]})
    https.set_debug_output($stdout)
    res = https.request(req)
    result = JSON.parse(res.body)

    if !(result.has_key? 'error_response') && !(result.has_key? 'error')
      session[:message] = 'Cache for all of your sites resources has been removed from Yottaa CDN.'
    else
      error = result["error"].nil? ? result["error_response"] : result["error"]
      session[:error] = 'Error received from flushing Yottaa optimizer cache:' + error.to_json
    end
    redirect '/heroku/resources/' + ENV["YOTTAA_SITE_ID"]
  end

  post "/purge" do
    paths = params[:paths]
    path_configs = []
    paths.split(/\r\n/).each do |path|
      path_configs.push({:condition => path, :name => "URI", :operator => "REGEX", :type => "html"})
    end
    uri = URI.parse(YOTTAA_API_URL_ROOT + "/sites/" + ENV["YOTTAA_SITE_ID"] +"/purge_cache?user_id=" + ENV["YOTTAA_USER_ID"])
    https = https_connection(uri)
    req = Net::HTTP::Post.new(uri, {CaseSensitiveString.new("YOTTAA-API-KEY") =>ENV["YOTTAA_API_KEY"]})
    req.body = path_configs.to_json
    https.set_debug_output($stdout)
    res = https.request(req)
    result = JSON.parse(res.body)

    if !(result.has_key? 'error_response') && !(result.has_key? 'error')
      session[:message] = 'Cache for given regular expressions has been removed from Yottaa CDN.'
    else
      error = result["error"].nil? ? result["error_response"] : result["error"]
      session[:error] = 'Error received from purging Yottaa optimizer cache:' + error.to_json
    end
    redirect '/heroku/resources/' + ENV["YOTTAA_SITE_ID"]
  end

end
