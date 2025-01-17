# frozen_string_literal: true

require 'rack'
require 'multi_json'
require_relative 'inbox'
require_relative 'default_operation_resolver'

module OpenapiFirst
  class Responder
    def initialize(namespace: nil, resolver: nil)
      @resolver = resolver || DefaultOperationResolver.new(namespace)
      @namespace = namespace
    end

    def call(env)
      operation = env[OpenapiFirst::OPERATION]
      res = Rack::Response.new
      handler = find_handler(operation)
      result = handler.call(inbox(env), res)
      res.write serialize(result) if result && res.body.empty?
      res[Rack::CONTENT_TYPE] ||= operation.content_types_for(res.status)&.first
      res.finish
    end

    private

    def inbox(env)
      Inbox.new(env).tap { |i| i.merge!(env[INBOX]) if env[INBOX] }
    end

    def find_handler(operation)
      handler = @resolver.call(operation)
      raise NotImplementedError, "Could not find handler for #{operation.name}" unless handler

      handler
    end

    def serialize(result)
      return result if result.is_a?(String)

      MultiJson.dump(result)
    end
  end
end
