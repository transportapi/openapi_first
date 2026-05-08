# frozen_string_literal: true

require 'active_support/isolated_execution_state'
require 'active_support/xml_mini'
require 'active_support/core_ext/hash/conversions'
require 'multi_json'
require 'rj_schema'
require_relative 'use_router'
require_relative 'validation_format'
require_relative 'string_based_coercion'
require_relative 'content_type'

module OpenapiFirst
  class ResponseValidation
    prepend UseRouter

    def initialize(app, _options = {})
      @app = app
    end

    def call(env)
      operation = env[OPERATION]
      return @app.call(env) unless operation

      response = @app.call(env)
      validate(response, operation)
      response
    end

    def validate(response, operation)
      status, headers, body = response.to_a
      return validate_status_only(operation, status) if status == 204

      content_type = headers[Rack::CONTENT_TYPE]
      response_schema = operation.response_schema_for(status, content_type)
      validate_response_body(response_schema, body, content_type) if response_schema
    end

    private

    def validate_status_only(operation, status)
      operation.response_for(status)
    end

    def validate_response_body(schema, response, content_type)
      full_body = +''
      response.each { |chunk| full_body << chunk }

      if ContentType.plain_text?(content_type)
        validate_plain_text(full_body, schema)
        return
      end

      data = if full_body.empty?
               {}
             elsif ContentType.xml?(content_type)
               StringBasedCoercion.coerce_types(Hash.from_xml(full_body), schema.raw_schema)
             else
               load_json(full_body)
             end

      error = RjSchema::Validator.new.validate(
        schema.raw_schema, data, continue_on_error: true, machine_errors: false, human_errors: true
      )[:human_errors]

      raise ::OpenapiFirst::ResponseBodyInvalidError, error unless error.nil? || error.empty?
    end

    def format_error(error)
      return "Write-only field appears in response: #{error['data_pointer']}" if error['type'] == 'writeOnly'

      JSONSchemer::Errors.pretty(error)
    end

    def load_json(string)
      MultiJson.load(string)
    rescue MultiJson::ParseError
      string
    end

    def validate_plain_text(body, schema)
      raw = schema.raw_schema

      # Strip leading/trailing whitespace from the response body before validation.
      # HTTP frameworks (e.g. Rails' render plain:) may append a trailing newline
      # to plain text responses. Stripping ensures validation matches the intended
      # content rather than failing on transport artifacts.
      body = body.strip

      if raw['type'] && raw['type'] != 'string'
        raise ::OpenapiFirst::ResponseBodyInvalidError,
              "Expected type '#{raw['type']}' but got a plain text response"
      end

      if raw['enum'] && !raw['enum'].include?(body)
        raise ::OpenapiFirst::ResponseBodyInvalidError,
              "Response body '#{body}' is not one of: #{raw['enum'].join(', ')}"
      end

      if raw['minLength'] && body.length < raw['minLength']
        raise ::OpenapiFirst::ResponseBodyInvalidError,
              "Response body is shorter than minLength: #{raw['minLength']}"
      end

      if raw['maxLength'] && body.length > raw['maxLength']
        raise ::OpenapiFirst::ResponseBodyInvalidError,
              "Response body is longer than maxLength: #{raw['maxLength']}"
      end

      if raw['pattern'] && !body.match?(Regexp.new(raw['pattern'])) # rubocop:disable Style/GuardClause
        raise ::OpenapiFirst::ResponseBodyInvalidError,
              "Response body does not match pattern: #{raw['pattern']}"
      end
    end
  end
end
