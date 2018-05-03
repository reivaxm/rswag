# frozen_string_literal: true

module Rswag
  module Specs
    module ExampleGroupHelpers # :nodoc: # rubocop:disable ModuleLength
      def path(template, metadata = {}, &block)
        metadata[:path_item] = { template: template }
        describe(template, metadata, &block)
      end

      %i[get post patch put delete head].each do |verb|
        define_method(verb) do |summary, &block|
          api_metadata = { operation: { verb: verb, summary: summary } }
          describe(verb, api_metadata, &block)
        end
      end

      %i[operationId deprecated security].each do |attr_name|
        define_method(attr_name) do |value|
          metadata[:operation][attr_name] = value
        end
      end

      # NOTE: 'description' requires special treatment because ExampleGroup
      # already defines a method with that name. Provide an override that
      # supports the existing functionality while also setting the appropriate
      # metadata if applicable
      def description(value = nil)
        return super() if value.nil?
        metadata[:operation][:description] = value
      end

      # These are array properties - note the splat operator
      %i[tags consumes produces schemes].each do |attr_name|
        define_method(attr_name) do |*value|
          metadata[:operation][attr_name] = value
        end
      end

      def parameter(attributes) # rubocop:disable AbcSize
        if attributes[:in] && attributes[:in].to_sym == :path
          attributes[:required] = true
        end

        if metadata.key?(:operation)
          metadata[:operation][:parameters] ||= []
          metadata[:operation][:parameters] << attributes
        else
          metadata[:path_item][:parameters] ||= []
          metadata[:path_item][:parameters] << attributes
        end
      end

      # rubocop:disable AbcSize,PerceivedComplexity,MethodLength,LineLength,CyclomaticComplexity
      def request_body(payload)
        type = payload.delete(:mime) || 'application/json'
        body_required = payload.delete(:body_required) || type == 'application/json'
        metadata[:operation][:requestBody] ||= {}
        metadata[:operation][:requestBody][:required] = body_required
        metadata[:operation][:requestBody][:content] ||= {}
        metadata[:operation][:requestBody][:content][type] ||= {}
        if %w[application/x-www-form-urlencoded multipart/form-data application/json application/xml].include?(type)
          metadata[:operation][:requestBody][:content][type][:schema] ||= { type: 'object' }
          metadata[:operation][:requestBody][:content][type][:schema][:properties] ||= {}
          if payload[:required] == true
            if metadata[:operation][:requestBody][:content][type][:schema][:required].nil? || \
               !metadata[:operation][:requestBody][:content][type][:schema][:required].is_a?(Array)
              metadata[:operation][:requestBody][:content][type][:schema][:required] = []
            end
            metadata[:operation][:requestBody][:content][type][:schema][:required] << payload[:name].to_s
            payload.delete(:required)
          end
          if payload[:example].present?
            if metadata[:operation][:requestBody][:content][type][:schema][:example].nil? || \
               !metadata[:operation][:requestBody][:content][type][:schema][:example].is_a?(Hash)
              metadata[:operation][:requestBody][:content][type][:schema][:example] = {}
            end
            metadata[:operation][:requestBody][:content][type][:schema][:example][payload[:name]] = payload.delete(:example)
          end
          name = payload.delete(:name)
          metadata[:operation][:requestBody][:content][type][:schema][:properties][name] = payload
        else
          metadata[:operation][:requestBody][:content][type][:schema] = payload
        end
      end
      # rubocop:enable AbcSize,PerceivedComplexity,MethodLength,LineLength,CyclomaticComplexity

      def response(code, description, metadata = {}, &block)
        metadata[:response] = { code: code, description: description }
        context(description, metadata, &block)
      end

      def schema(value)
        metadata[:response][:schema] = value
      end

      def content(payload)
        type = payload.delete(:mime) || 'application/json'
        metadata[:response][:content] ||= {}
        metadata[:response][:content][type] ||= {}
        metadata[:response][:content][type][:schema] = payload
      end

      def header(name, attributes)
        metadata[:response][:headers] ||= {}
        metadata[:response][:headers][name] = attributes
      end

      # NOTE: Similar to 'description', 'examples' need to handle the case when
      # being invoked with no params to avoid overriding 'examples' method of
      # rspec-core ExampleGroup
      def examples(example = nil)
        return super() if example.nil?
        metadata[:response][:examples] = example
      end

      # rubocop:disable AbcSize,MethodLength,
      # rubocop:disable CyclomaticComplexity,PerceivedComplexity
      def run_test!(args = {}, &block)
        # NOTE: rspec 2.x support
        if RSPEC_VERSION < 3
          before do
            args[:before_request].call if args[:before_request].present?
            submit_request(example.metadata, args[:debug].present?)
          end

          it "returns a #{metadata[:response][:code]} response" do
            assert_response_matches_metadata(metadata)
            yield(response) if block
          end
        else
          before do |example|
            args[:before_request].call if args[:before_request].present?
            submit_request(example.metadata, args[:debug].present?)
          end

          it "returns a #{metadata[:response][:code]} response" do |example|
            if args[:debug].present?
              puts "#{'=' * 10} BEGIN DEBUG #{'=' * 10}"
              puts 'Response headers'
              puts response.headers.inspect
              puts 'Response body'
              puts response.body
              puts "#{'=' * 11} END DEBUG #{'=' * 11}"
            end
            assert_response_matches_metadata(example.metadata, &block)
            example.instance_exec(response, &block) if block
          end
        end
      end
      # rubocop:enable AbcSize,MethodLength
      # rubocop:enable CyclomaticComplexity,PerceivedComplexity
    end
  end
end
