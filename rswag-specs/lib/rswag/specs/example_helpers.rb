# frozen_string_literal: true

require 'rswag/specs/request_factory'
require 'rswag/specs/response_validator'

module Rswag
  module Specs
    module ExampleHelpers # :nodoc:
      def submit_request(metadata, debug = false)
        request = RequestFactory.new.build_request(metadata, self)

        debug_request_logger(request) if debug

        if RAILS_VERSION < 5
          send(request[:verb], request[:path],
               request[:payload], request[:headers])
        else
          send(request[:verb], request[:path],
               params: request[:payload], headers: request[:headers])
        end
      end

      def assert_response_matches_metadata(metadata, debug = false)
        debug_response_logger(response) if debug
        ResponseValidator.new.validate!(metadata, response)
      end

      private

      def debug_request_logger(request) # rubocop:disable AbcSize
        puts "#{'=' * 10} BEGIN DEBUG #{'=' * 10}"
        puts 'Request verb'
        puts request[:verb]
        puts 'Request path'
        puts request[:path]
        puts 'Request payload'
        puts request[:payload].inspect
        puts 'Request headers'
        puts request[:headers].inspect
        puts "#{'=' * 11} END DEBUG #{'=' * 11}"
      end

      def debug_response_logger(response)
        puts "#{'=' * 10} BEGIN DEBUG #{'=' * 10}"
        puts 'Response headers'
        puts response.headers.inspect
        puts 'Response body'
        puts response.body
        puts "#{'=' * 11} END DEBUG #{'=' * 11}"
      end
    end
  end
end
