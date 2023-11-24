# frozen_string_literal: true

require 'yaml'
require 'json_refs'
require_relative 'openapi_first/definition'
require_relative 'openapi_first/version'
require_relative 'openapi_first/errors'
require_relative 'openapi_first/inbox'
require_relative 'openapi_first/router'
require_relative 'openapi_first/request_validation'
require_relative 'openapi_first/response_validator'
require_relative 'openapi_first/response_validation'
require_relative 'openapi_first/responder'
require_relative 'openapi_first/app'

module OpenapiFirst
  OPERATION = 'openapi_first.operation'
  PARAMETERS = 'openapi_first.parameters'
  REQUEST_BODY = 'openapi_first.parsed_request_body'
  INBOX = 'openapi_first.inbox'
  HANDLER = 'openapi_first.handler'

  def self.env
    ENV['RACK_ENV'] || ENV['HANAMI_ENV'] || ENV.fetch('RAILS_ENV', nil)
  end

  def self.load(spec_path, only: nil)
    resolved = Dir.chdir(File.dirname(spec_path)) do
      content = YAML.load_file(File.basename(spec_path))
      JsonRefs.call(content, resolve_local_ref: true, resolve_file_ref: true)
    end
    resolved['paths'].filter!(&->(key, _) { only.call(key) }) if only
    add_null_types!(resolved)
    Definition.new(resolved, spec_path)
  end

  def self.app(
    spec,
    namespace:,
    router_raise_error: false,
    request_validation_raise_error: false,
    response_validation: false
  )
    spec = OpenapiFirst.load(spec) unless spec.is_a?(Definition)
    App.new(
      nil,
      spec,
      namespace: namespace,
      router_raise_error: router_raise_error,
      request_validation_raise_error: request_validation_raise_error,
      response_validation: response_validation
    )
  end

  def self.middleware(
    spec,
    namespace:,
    router_raise_error: false,
    request_validation_raise_error: false,
    response_validation: false
  )
    spec = OpenapiFirst.load(spec) unless spec.is_a?(Definition)
    AppWithOptions.new(
      spec,
      namespace: namespace,
      router_raise_error: router_raise_error,
      request_validation_raise_error: request_validation_raise_error,
      response_validation: response_validation
    )
  end

  def self.add_null_types!(schema_hash)
    # end of recursion condition
    return unless schema_hash.is_a?(Hash)

    if schema_hash['nullable']
      type = schema_hash.delete('type')
      schema_hash['oneOf'] = [{ 'type' => 'null' }, { 'type' => type }] if type
    end
    schema_hash.each_value do |sub_schema|
      add_null_types!(sub_schema)
    end
  end

  private_class_method :add_null_types!

  class AppWithOptions
    def initialize(spec, options)
      @spec = spec
      @options = options
    end

    def new(app)
      App.new(app, @spec, **@options)
    end
  end
end
