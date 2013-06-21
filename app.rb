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

  YOTTAA_CUSTOM_HEADER = {CaseSensitiveString.new("YOTTAA-API-KEY") =>'39e8b9b0b1000130d279123138106137'}
  YOTTAA_API_URL_ROOT = "https://api-dev.yottaa.com/partners/51b0cd1bebe2bb3069000f0d"

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
        uri = URI.parse(YOTTAA_API_URL_ROOT + "/accounts/" + user_id + "/sites/" + site_id)
        https = https_connection(uri)
        req = Net::HTTP::Get.new(uri, YOTTAA_CUSTOM_HEADER)
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
    halt 403, 'not logged in' unless session[:heroku_sso]
    #response.set_cookie('heroku-nav-data', value: session[:heroku_sso])
    @resource = session[:resource]
    @email    = session[:email]
    haml :index
  end

  def sso
    STDOUT.puts ENV['SSO_SALT']
    STDOUT.puts params[:id]
    STDOUT.puts params[:timestamp]
    pre_token = params[:id] + ':' + ENV['SSO_SALT'] + ':' + params[:timestamp]
    token = Digest::SHA1.hexdigest(pre_token).to_s
    halt 403 if token != params[:token]
    halt 403 if params[:timestamp].to_i < (Time.now - 2*60).to_i

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
    options = json_body.fetch('options', {})
    first_name = options['first_name'].nil? ? "" : options['first_name']
    last_name = options['last_name'].nil? ? "" : options['last_name']
    phone = options['phone'].nil? ? "" : options['phone']
    email = options['email'].nil? ? json_body.fetch('heroku_id') : options['email']
    # TODO: figure out the default custom domain name?
    site = options['site'].nil? ? "" : options['site']
    plan = json_body.fetch("plan", "free")
    if !email.empty? && !site.empty?
      STDOUT.puts "Creating a new Yottaa account"

      uri = URI.parse(YOTTAA_API_URL_ROOT + "/accounts")
      https = https_connection(uri)
      req = Net::HTTP::Post.new(uri, YOTTAA_CUSTOM_HEADER)
      req.set_form_data({"first_name" => first_name, "last_name" => last_name, "email" => email, "site" => site, "phone" => phone, "plan" => plan})
      https.set_debug_output($stdout)

      res = https.request(req)
      result = JSON.parse(res.body)

      if !result.has_key? 'error'
        status 201
        body({
                 :id => result["site_id"],
                 :config => {"YOTTAA_SITE_ID" => result["site_id"], "YOTTAA_USER_ID" => result["user_id"], "YOTTAA_API_KEY" => result["api_key"]},
                 :message => 'Dear ' + first_name + ' ' + last_name +', your Yottaa account is now provisioned!'
             }.to_json)
      else
        status 422
        body(result['error'].to_json)
      end
    else
      status 422
      body({:error => 'Valid email and site url must be provided.'}.to_json)
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
    uri = URI.parse(YOTTAA_API_URL_ROOT + "/accounts/" + user_id + "/sites/" +site_id)
    https = https_connection(uri)
    req = Net::HTTP::Delete.new(uri, YOTTAA_CUSTOM_HEADER)
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
end
