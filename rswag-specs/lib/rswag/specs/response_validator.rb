require 'active_support/core_ext/hash/slice'
require 'json-schema'
require 'json'
require 'rswag/specs/extended_schema'

module Rswag
  module Specs
    class UnexpectedResponse < StandardError; end
    class UnexpectedContent < StandardError; end
    class ResponseValidator

      def initialize(config = ::Rswag::Specs.config)
        @config = config
      end

      def validate!(metadata, response)
        swagger_doc = @config.get_swagger_doc(metadata[:swagger_doc])

        validate_code!(metadata, response.code)
        validate_headers!(metadata, response.headers)
        validate_body!(metadata, swagger_doc, response.body)
      end

      private

      def validate_code!(metadata, code)
        expected = metadata[:response][:code].to_s
        return true if code == expected
        raise(
          UnexpectedResponse,
          "Expected response code '#{code}' to match '#{expected}'"
        )
      end

      def validate_headers!(metadata, headers)
        expected = (metadata[:response][:headers] || {}).keys
        expected.each do |name|
          next if headers[name.to_s].present?
          raise(
            UnexpectedResponse,
            "Expected response header #{name} to be present"
          )
        end
      end

      def validate_body!(metadata, swagger_doc, body)
        if swagger_doc[:openapi].present?
          validate_body_openapi3!(metadata, swagger_doc, body)
        else
          validate_body_swagger2!(metadata, swagger_doc, body)
        end
      end

      def validate_body_swagger2!(metadata, swagger_doc, body)
        response_schema = metadata[:response][:schema]
        return if response_schema.nil?

        validate_json!(
          response_schema.merge(swagger_doc.slice(:definitions)),
          body
        )
      end

      def validate_body_openapi3!(metadata, swagger_doc, body)
        response_contents = metadata[:response][:content]
        return if response_contents.nil?
        response_contents.each do |mime, schema|
          case mime
          when 'application/json'
            validate_json!(schema[:schema].merge(swagger_doc.slice(:components)), body)
          else
            raise(UnexpectedContent, "No validator for content with mime : #{mime}")
          end
        end
      end

      def validate_json!(response_schema, body)
        validation_schema = response_schema.merge(
          '$schema' => 'http://tempuri.org/rswag/specs/extended_schema'
        )
        errors = JSON::Validator.fully_validate(validation_schema, body)
        return true unless errors.any?
        raise(
          UnexpectedResponse,
          "Expected response body to match schema: #{errors[0]}"
        )
      end
    end
  end
end
