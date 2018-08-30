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

      # rubocop:disable AbcSize,MethodLength,LineLength
      def request_body(payload)
        type = payload.delete(:mime) || 'application/json'
        body_required = payload.delete(:body_required) || type == 'application/json'
        metadata[:operation][:requestBody] ||= {}
        metadata[:operation][:requestBody][:required] = body_required
        metadata[:operation][:requestBody][:content] ||= {}
        metadata[:operation][:requestBody][:content][type] ||= {}
        if %w[
          application/x-www-form-urlencoded
          multipart/form-data
          application/json application/xml
        ].include?(type)
          name = payload.delete(:name)
          raise(AttributeError, 'Name is missing') if name.blank?
          base = metadata[:operation][:requestBody][:content][type][:schema]
          output = node_finder(base, name) do |data, key_name|
            data = body_payload_requirement(payload, key_name, data)
            data = body_payload_examples(payload, key_name, data)
            data[:properties][key_name] = payload
            data
          end
          metadata[:operation][:requestBody][:content][type][:schema] = output
        else
          metadata[:operation][:requestBody][:content][type][:schema] = payload
        end
      end
      # rubocop:enable AbcSize,MethodLength,LineLength

      def node_finder(node, name) # rubocop:disable MethodLength,AbcSize
        node ||= { type: 'object', properties: {} }
        names = name.to_s.split('/').map(&:to_sym)
        name = names.pop.to_sym
        if names.empty?
          node = yield(node, name)
        else
          node_path = names.map{ |n| [:properties, n] }.flatten
          child_data = node.dig(*node_path)
          unless child_data
            builder = Hash.new do |h, k|
              h = { k.to_sym => { type: 'object', properties: {} }}
            end
            tree_path = []
            names.each do |digged_name|
              tree_path << :properties
              tree_path << digged_name
              next if node.dig(*tree_path)
              if tree_path.length > 2
                key_done = tree_path.reject { |p| p == :properties }
                key_done[0...-1].inject(node) do |acc, key|
                  acc[:properties].public_send(:[], key)
                end.public_send(:[]=, :properties, builder[digged_name])
              else
                node[:properties] = builder[digged_name]
              end
            end
          end
          names.inject(node) do |acc, key|
            acc[:properties].public_send(:[], key)
          end.merge(yield(node.dig(*node_path), name))
        end
        node
      end

      def body_payload_requirement(payload, name, output = {})
        if payload[:required] == true
          if output[:required].nil? || \
             !output[:required].is_a?(Array)
            output[:required] = []
          end
          output[:required] << name.to_s
          payload.delete(:required)
        end
        output
      end

      def body_payload_examples(payload, name, output = {})
        if payload[:example].present?
          if output[:example].nil? || \
             !output[:example].is_a?(Hash)
            output[:example] = {}
          end
          output[:example][name] = payload.delete(:example)
        end
        output
      end

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

      # rubocop:disable AbcSize,MethodLength
      def run_test!(args = {}, &block)
        # NOTE: rspec 2.x support
        if RSPEC_VERSION < 3
          before do
            args[:before_request].call if args[:before_request].present?
            submit_request(example.metadata, args[:debug].present?)
          end

          it "returns a #{metadata[:response][:code]} response" do
            assert_response_matches_metadata(metadata, args[:debug].present?)
            yield(response) if block
          end
        else
          before do |example|
            args[:before_request].call if args[:before_request].present?
            submit_request(example.metadata, args[:debug].present?)
          end

          it "returns a #{metadata[:response][:code]} response" do |example|
            assert_response_matches_metadata(
              example.metadata, args[:debug].present?
            )
            example.instance_exec(response, &block) if block
          end
        end
      end
      # rubocop:enable AbcSize,MethodLength
    end
  end
end
