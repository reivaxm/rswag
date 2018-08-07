# frozen_string_literal: true

require 'rswag/api/middleware'

module Rswag # :nodoc:
  module Api # :nodoc:
    class Engine < ::Rails::Engine # :nodoc:
      isolate_namespace Rswag::Api

      initializer 'rswag-api.initialize' do
        middleware.use Rswag::Api::Middleware, Rswag::Api.config
      end
    end
  end
end
