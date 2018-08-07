# frozen_string_literal: true

require 'json'
require 'yaml'

module Rswag
  module Api
    class Middleware # :nodoc:
      def initialize(app, config)
        @app = app
        @config = config
      end

      def call(env)
        path = env['PATH_INFO']
        filename = "#{@config.resolve_swagger_root(env)}/#{path}"
        if env['REQUEST_METHOD'] == 'GET' && File.file?(filename)
          swagger = load(filename)
          @config.swagger_filter &.call(swagger, env)
          return respond(swagger)
        end

        @app.call(env)
      end

      private

      def load(filename)
        case File.extname(filename)
        when /ya?ml/
          @kind = :yaml
          load_yaml(filename)
        when 'json'
          @kind = :json
          load_json(filename)
        else raise(StandardError, 'Unsupported format')
        end
      end

      def respond(data)
        if @kind == :yaml
          ['200', { 'Content-Type' => 'application/x-yaml' }, [data.to_yaml]]
        else
          ['200', { 'Content-Type' => 'application/json' }, [JSON.dump(data)]]
        end
      end

      def load_yaml(filename)
        YAML.load_file(filename)
      end

      def load_json(filename)
        JSON.parse(File.read(filename))
      end
    end
  end
end
