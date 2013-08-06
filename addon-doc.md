[Yottaa](http://addons.heroku.com/yottaa) is an [add-on](http://addons.heroku.com) for web and mobile optimization, CDN, DNS and Firewall with integrated monitoring.

##### Datacenter Optimization
Accelerate server-side performance and eliminate latency with powerful content optimization. Yottaa enables everything from push-button acceleration to robust server-side content optimizations, without the complexity and people-hours required by individual or DIY solutions

##### Middle Mile Optimization (CDN)
Accelerate content delivery with cutting-edge CDN federation technology, leveraging a hybrid architecture of physical and cloud datacenters to ensure the most efficient and resilient network architecture possible.

##### Content Optimization (Last Mile)
Reduce payload, minimize round trip requests, and apply network optimizations to deliver the right content to the right device – right on time

##### Device & Browser Optimization
Minimize client-side processing and optimize above-the-fold rendering to provide the best end user experience across all devices: desktops, tablets and phones

##### Integrated Security
Guarantee resource elasticity to scale for traffic spikes so your success does not result in unexpected downtime or damage to your brand. Block unwanted and throttle low-priority traffic to ensure your target visitors have the end user experience they demand.

Yottaa is accessible via an API and has supported client libraries for [Java]|[Ruby](#using-with-ruby-on-rails).

## Provisioning the add-on

Yottaa can be attached to a Heroku application via the  CLI:

> A list of all plans available can be found [here](http://addons.heroku.com/yottaa).

### Sign up a new Yottaa account

To provision a new Yottaa account for your site, you can run the `heroku addons:add` command with following parameters

`first_name`: Account owner's first name

`last_name`: Account owner's last name

`email`: Account owner's email

`phone`: Account owner's phone number

`site`: URL of the target site

```term
$ heroku addons:add yottaa --first_name=John --last_name=Smith --email=john.smith@yottaa.com --phone=123456789 --site=http://www.yoursite.com
Dear John Smith, your Yottaa account is now provisioned!
Use `heroku addons:docs yottaa:free` to view documentation.
```

Although parameters are optional, it is highly recommended to provide all of them.


### Register an Existing Yottaa account

If you already have a Yottaa account and added your site through Yottaa apps console, you can provision your Yottaa add-on using `user_id`, `api_key` and `site_id` parameters.

```term
$ heroku addons:add yottaa --user_id=51fcf311ea2e0c17d70003cs --api_key=8868d820de630130be5e12313d08f870 --site_id=51fcf311ea2e0c17d70003cf
Dear Customer, your Yottaa account is now provisioned!
Use `heroku addons:docs yottaa:free` to view documentation.
```

You will need to login [Yottaa Apps Console](http://apps.yottaa.com) to find out the above three parameters.

Once Yottaa has been added three custom settings, `YOTTAA_API_KEY`, `YOTTAA_SITE_ID` and `YOTTAA_USER_ID`, will be available in the app configuration.

This can be confirmed using the `heroku config:get` command.

```term
$ heroku config
=== yottaa-heroku-app Config Vars
YOTTAA_API_KEY: 8868d820de630130be5e12313d08f870
YOTTAA_SITE_ID: 51fcf311ea2e0c17d70003cf
YOTTAA_USER_ID: 51fcf311ea2e0c17d70003cs
```

After installing Yottaa you will need to configure your DNS records to fully integrate your application with the add-on.

## DNS setup

### Setup Custom Domain for Your Heroku App

Your app on Heroku is accessible via its `herokuapp.com` app subdomain. E.g., for an app named `yottaa-heroku-app` it’s available at `yottaa-heroku-app.herokuapp.com`. To serve traffic on your own domain, e.g., `heroku.bestwebsitemonitoring.info`, you need to configure your application with a custom domain.

In general, you will need to take two steps


1. Tell Heroku which custom domains are specific to your application

```term
$ heroku domains:add heroku.bestwebsitemonitoring.info
Adding heroku.bestwebsitemonitoring.info to yottaa-heroku-app... done
```

2. Configure your application’s DNS to point to Heroku e.g. adding a CNAME record pointing the subdomain to your app’s Heroku herokuapp.com hostname.

| Record        | Name          | Target  |
| ------------- |:-------------:|:-------:|
| `CNAME`       | heroku.bestwebsitemonitoring.info | yottaa-heroku-app.herokuapp.com |

For more information on setting up Heroku custom domains, please refer to [this document](https://devcenter.heroku.com/articles/custom-domains).

### Activate Your Yottaa Account

Once you configure your custom domain for your Heroku app, next step will be activating your Yottaa account that you have signed up or registered through the Heroku command line.

1. First, locate your site's Yottaa CNAME by logging in [Yottaa Apps Console](http://apps.yottaa.com) and browsing to your site dashboard.
2. Then modify the `CNAME` record you just created for your Heroku App with the Yotaa CNAME.

| Record        | Name          | Target  |
| ------------- |:-------------:|:-------:|
| `CNAME`       | heroku.bestwebsitemonitoring.info | 72620360de5d013012371231381401ec.yottaa.net |


## Local setup

### Environment setup

After provisioning the add-on it’s necessary to locally replicate the config vars so your development environment can operate against the service.

Use [Foreman](config-vars#local-setup) to configure, run and manage process types specified in your app’s [Procfile](procfile). Foreman reads configuration variables from an .env file. Use the following command to add the Yottaa config values retrieved from heroku config to `.env`.

```term
$ heroku config -s | grep YOTTAA >> .env
$ more .env
```

> warning
> Credentials and other sensitive configuration values should not be committed to source-control. In Git exclude the .env file with: `echo .env >> .gitignore`.

## Using with Ruby On Rails

```ruby
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

STDOUT.puts "Retrieve details of the site you have registerd with Yottaa."
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
```

## Using with Python/Django


## Using with Java

[[Repeat structure from Rails 3.x section for each supported language]]

## Monitoring & Logging

## Dashboard

> callout
> For more information on the features available within the Yottaa dashboard please see the docs at [mysite.com/docs](mysite.com/docs).

The Yottaa dashboard allows you to [[describe dashboard features]].

The dashboard can be accessed via the CLI:

```term
$ heroku addons:open yottaa
Opening yottaa for yottaa-heroku-app…
```

or by visiting the [Heroku apps web interface](http://heroku.com/myapps) and selecting the application in question. Select Yottaa from the Add-ons menu.

## Troubleshooting

## Migrating between plans

> note
> Application owners should carefully manage the migration timing to ensure proper application function during the migration process.

Use the `heroku addons:upgrade` command to migrate to a new plan.

```term
$ heroku addons:upgrade yottaa:enterprise
-----> Upgrading yottaa:enterprise to yottaa-heroku-app... done, v5 ($4999/mo)
       Your plan has been updated to: yottaa:enterprise
```

## Removing the add-on

Yottaa can be removed via the  CLI.

> warning
> This will destroy all associated data and cannot be undone!

```term
$ heroku addons:remove yottaa
Removing yottaa:free on yottaa-heroku-app... done, v5 (free)

## Support

All Yottaa support and runtime issues should be submitted via on of the [Heroku Support channels](support-channels). Any non-support related issues or product feedback is welcome at [[your channels]].