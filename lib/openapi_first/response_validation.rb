# frozen_string_literal: true

require 'multi_json'
require 'rj_schema'
require_relative 'use_router'
require_relative 'validation_format'

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
      validate_response_body(response_schema, body) if response_schema
    end

    private

    def validate_status_only(operation, status)
      operation.response_for(status)
    end

    def validate_response_body(schema, response)
      full_body = +''
      response.each { |chunk| full_body << chunk }
      data = full_body.empty? ? {} : load_json(full_body)

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
  end
end
