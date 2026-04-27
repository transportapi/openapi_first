# frozen_string_literal: true

require 'active_support/isolated_execution_state'
require 'active_support/xml_mini'
require 'active_support/core_ext/hash/conversions'
require 'multi_json'
require_relative 'content_type'

module OpenapiFirst
  class BodyParserMiddleware
    def initialize(app, options = {})
      @app = app
      @raise = options.fetch(:raise_error, false)
    end

    RACK_INPUT = 'rack.input'
    ROUTER_PARSED_BODY = 'router.parsed_body'

    def call(env)
      env[ROUTER_PARSED_BODY] = parse_body(env)
      @app.call(env)
    rescue BodyParsingError => e
      raise if @raise

      err = { title: "Failed to parse body as #{env['CONTENT_TYPE']}", status: '400' }
      err[:detail] = e.cause unless ENV['RACK_ENV'] == 'production'
      errors = [err]

      Rack::Response.new(
        MultiJson.dump(errors: errors),
        400,
        Rack::CONTENT_TYPE => 'application/vnd.api+json'
      ).finish
    end

    private

    def parse_body(env)
      request = Rack::Request.new(env)
      body = read_body(request)
      return if body.empty?

      return MultiJson.load(body) if request.media_type =~ (/json/i) && (request.media_type =~ /json/i)
      return Hash.from_xml(body) if ContentType.xml?(request.content_type)
      return request.POST if request.form_data?

      body
    rescue MultiJson::ParseError, REXML::ParseException, Nokogiri::XML::SyntaxError => e
      raise BodyParsingError, e
    end

    def read_body(request)
      body = request.body.read
      request.body.rewind
      body
    end
  end
end
