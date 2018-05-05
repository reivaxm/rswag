# frozen_string_literal: true

require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/hash/conversions'
require 'json'

module Rswag
  module Specs
    class RequestFactory # rubocop:disable ClassLength
      def initialize(config = ::Rswag::Specs.config)
        @config = config
      end

      def build_request(metadata, example)
        swagger_doc = @config.get_swagger_doc(metadata[:swagger_doc])
        parameters = expand_parameters(metadata, swagger_doc, example)

        {}.tap do |request|
          add_verb(request, metadata)
          add_path(request, metadata, swagger_doc, parameters, example)
          add_headers(request, metadata, swagger_doc, parameters, example)
          add_payload(request, metadata, swagger_doc, parameters, example)
        end
      end

      private

      def expand_parameters(metadata, swagger_doc, example)
        operation_params = metadata[:operation][:parameters] || []
        path_item_params = metadata[:path_item][:parameters] || []
        request_body_params = explore_request_body_params(metadata)
        security_params = derive_security_params(metadata, swagger_doc)

        operation_params
          .concat(request_body_params)
          .concat(path_item_params)
          .concat(security_params)
          .map { |p| p['$ref'] ? resolve_parameter(p['$ref'], swagger_doc) : p }
          .uniq { |p| p[:name] }
          .reject { |p| p[:required] == false && !example.respond_to?(p[:name]) }
      end

      def derive_security_params(metadata, swagger_doc)
        requirements = metadata[:operation][:security] || \
                       swagger_doc[:security] || []
        scheme_names = requirements.flat_map(&:keys)
        schemes = if swagger_doc[:openapi].present?
                    swagger_doc.dig(:components, :securitySchemes)
                  else
                    swagger_doc[:securityDefinitions]
                  end || {}
        schemes.slice(*scheme_names).values.map do |scheme|
          param = if scheme[:type] == :apiKey
                    scheme.slice(:name, :in)
                  else
                    { name: 'Authorization', in: :header }
                  end
          param.merge(type: :string, required: requirements.one?)
        end
      end

      def explore_request_body_params(metadata)
        (metadata.dig(:operation, :requestBody, :content) || {}).map do |data|
          required = data[1].dig(:schema, :required) || []
          (data[1].dig(:schema, :properties) || {}).keys.map do |name|
            { name: name, required: required.include?(name) }
          end
        end.flatten
      end

      def resolve_parameter(ref, swagger_doc)
        key = ref.sub('#/parameters/', '').to_sym
        definitions = swagger_doc[:parameters]
        raise "Referenced parameter '#{ref}' must be defined" \
          unless definitions && definitions[key]
        definitions[key]
      end

      def add_verb(request, metadata)
        request[:verb] = metadata[:operation][:verb]
      end

      def add_path(request, metadata, swagger_doc, parameters, example)
        template = (swagger_doc[:basePath] || '') + \
                   metadata[:path_item][:template]

        request[:path] = template.tap do |tpl|
          parameters.select { |p| p[:in] == :path }.each do |p|
            tpl.gsub!("{#{p[:name]}}", example.send(p[:name]).to_s)
          end

          query_string = []
          parameters.select { |p| p[:in] == :query }.each do |p|
            next unless example.try(p[:name])
            query_string << build_query_string_part(
              swagger_doc, p, example.send(p[:name])
            )
          end
          tpl.concat("?#{query_string.join('&')}") unless query_string.empty?
        end
      end

      def build_query_string_part(swagger_doc, param, value)
        name = param[:name]
        type = if swagger_doc[:openapi].present?
                 param[:schema][:type]
               else
                 param[:type]
               end
        return "#{name}=#{value}" unless type.to_sym == :array

        case param[:collectionFormat]
        when :ssv
          "#{name}=#{value.join(' ')}"
        when :tsv
          "#{name}=#{value.join('\t')}"
        when :pipes
          "#{name}=#{value.join('|')}"
        when :multi
          value.map { |v| "#{name}=#{v}" }.join('&')
        else
          "#{name}=#{value.join(',')}" # csv is default
        end
      end

      def add_headers(request, metadata, swagger_doc, parameters, example)
        tuples = parameters
                 .select { |p| p[:in] == :header }
                 .map do |p|
          begin
            [p[:name], example.send(p[:name]).to_s]
          rescue NoMethodError
            nil
          end
        end.compact

        # Accept header
        produces = if swagger_doc[:openapi].present?
                     (metadata.dig(:response) || {}).map do |data|
                       next unless data[0] == :content
                       (data[1] || {}).keys
                     end.flatten.compact
                   else
                     metadata[:operation][:produces] || swagger_doc[:produces]
                   end
        if produces
          accept = example.respond_to?(:Accept) ? example.send(:Accept) : produces.first
          tuples << ['Accept', accept]
        end

        # Content-Type header
        consumes = if swagger_doc[:openapi].present?
                     (metadata.dig(:operation, :requestBody, :content) || {}).keys
                   else
                     metadata[:operation][:consumes] || swagger_doc[:consumes]
                   end
        if consumes
          content_type = example.respond_to?(:'Content-Type') ? example.send(:'Content-Type') : consumes.first
          tuples << ['Content-Type', content_type]
        end

        # Rails test infrastructure requires rackified headers
        rackified_tuples = tuples.map do |pair|
          [
            case pair[0]
            when 'Accept' then 'HTTP_ACCEPT'
            when 'Content-Type' then 'CONTENT_TYPE'
            when 'Authorization' then 'HTTP_AUTHORIZATION'
            else pair[0]
            end,
            pair[1]
          ]
        end

        request[:headers] = Hash[rackified_tuples]
      end

      def add_payload(request, metadata, swagger_doc, parameters, example)
        content_type = request[:headers]['CONTENT_TYPE']
        return if content_type.nil?

        request[:payload] = if %w[
          application/x-www-form-urlencoded
          multipart/form-data
        ].include?(content_type)
                              build_form_payload(
                                metadata, swagger_doc,
                                parameters, example,
                                content_type
                              )
                            elsif content_type == 'application/json'
                              build_json_payload(
                                metadata, swagger_doc,
                                parameters, example,
                                content_type
                              )
                            elsif content_type == 'application/xml'
                              build_xml_payload(
                                metadata, swagger_doc,
                                parameters, example,
                                content_type
                              )
                            end
      end

      def build_form_payload(metadata, swagger_doc, parameters, example, content_type)
        # See http://seejohncode.com/2012/04/29/quick-tip-testing-multipart-uploads-with-rspec/
        # Rather that serializing with the appropriate encoding (e.g. multipart/form-data),
        # Rails test infrastructure allows us to send the values directly as a hash
        # PROS: simple to implement, CONS: serialization/deserialization is bypassed in test
        tuples = if swagger_doc[:openapi].present?
                   explore_request_body_payload(metadata, example, content_type)
                 else
                   parameters
                     .select { |p| p[:in] == :formData }
                     .map { |p| [p[:name], example.send(p[:name])] }
                 end
        Hash[tuples]
      end

      def build_json_payload(metadata, swagger_doc, parameters, example, content_type)
        if swagger_doc[:openapi].present?
          build_form_payload(metadata, swagger_doc, parameters, example, content_type).to_json
        else
          body_param = parameters.select { |p| p[:in] == :body }.first
          body_param ? example.send(body_param[:name]).to_json : nil
        end
      end

      def build_xml_payload(metadata, swagger_doc, parameters, example, content_type)
        root = metadata.dig(:path_item, :template) &.match(%r{/([^/]+)$})
        root = root[1] || 'root'
        build_form_payload(
          metadata, swagger_doc, parameters, example, content_type
        ).to_xml(root: root)
      end

      def explore_request_body_payload(metadata, example, content_type)
        (metadata.dig(:operation, :requestBody, :content) || {}).map do |data|
          next if data[0] != content_type
          (data[1].dig(:schema, :properties) || {}).keys.map do |name|
            next unless example.try(name)
            [name, example.send(name)]
          end.compact
        end.try(:first)
      end
    end
  end
end
