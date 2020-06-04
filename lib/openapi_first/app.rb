# frozen_string_literal: true

require 'rack'
require 'logger'

module OpenapiFirst
  class App
    def initialize(parent_app, spec, namespace:, raise_error:)
      @stack = Rack::Builder.app do
        freeze_app
        use OpenapiFirst::Router, spec: spec, raise_error: raise_error, parent_app: parent_app
        use OpenapiFirst::RequestValidation, raise_error: raise_error
        use OpenapiFirst::ResponseValidation if raise_error
        run OpenapiFirst::Responder.new(
          spec: spec,
          namespace: namespace
        )
      end
    end

    def call(env)
      @stack.call(env)
    end
  end
end
