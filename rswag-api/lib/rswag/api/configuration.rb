# frozen_string_literal: true

module Rswag # :nodoc:
  module Api # :nodoc:
    class Configuration # :nodoc:
      attr_accessor :swagger_root, :swagger_filter

      def resolve_swagger_root(env)
        path_params = env['action_dispatch.request.path_parameters'] || {}
        path_params[:swagger_root] || swagger_root
      end
    end
  end
end
