require 'routemaster'
require 'sinatra'
require 'rack/ssl'
require 'routemaster/middleware/authentication'
require 'routemaster/middleware/redis_authentication'
require 'routemaster/controllers/pulse'
require 'routemaster/controllers/topics'
require 'routemaster/controllers/health'
require 'routemaster/controllers/subscriber'
require 'routemaster/controllers/key_registration'
require 'routemaster/mixins/log_exception'
require 'routemaster/models/client_token'

module Routemaster
  class Application < Sinatra::Base
    include Mixins::LogException

    configure do
      # Do capture any errors. We're logging them ourselves
      set :raise_errors, false
    end

    use Rack::SSL
    use Controllers::Health

    use Controllers::KeyRegistration
    use Middleware::RedisAuthentication, keys: ->{ Models::ClientToken.get_all}
    use Controllers::Pulse
    use Controllers::Topics
    use Controllers::Subscriber

    not_found do
      content_type 'text/plain'
      body ''
    end

    error do
      deliver_exception env['sinatra.error']
    end
  end
end
