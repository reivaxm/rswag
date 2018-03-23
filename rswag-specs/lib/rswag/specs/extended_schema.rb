# frozen_string_literal: true

require 'json-schema'

module Rswag
  module Specs # :nodoc:
    class ExtendedSchema < JSON::Schema::Draft4 # :nodoc:
      def initialize
        super
        @attributes['type'] = ExtendedTypeAttribute
        @uri = URI.parse('http://tempuri.org/rswag/specs/extended_schema')
        @names = ['http://tempuri.org/rswag/specs/extended_schema']
      end
    end

    class ExtendedTypeAttribute < JSON::Schema::TypeV4Attribute # :nodoc:
      def self.validate( # rubocop:disable Metrics/ParameterLists
        current_schema,
        data,
        fragments,
        processor,
        validator,
        options = {}
      )
        return if data.nil? && current_schema.schema['x-nullable'] == true
        super
      end
    end

    JSON::Validator.register_validator(ExtendedSchema.new)
  end
end
