# frozen_string_literal: true

module OpenapiFirst
  module TypeCoercion
    module_function

    def coerce_value(value, schema)
      return to_boolean(value) if schema['type'] == 'boolean'

      begin
        return Integer(value, 10) if schema['type'] == 'integer'
        return Float(value) if schema['type'] == 'number'
      rescue ArgumentError
        value
      end
      value
    end

    def to_boolean(value)
      return true if value == 'true'
      return false if value == 'false'

      value
    end
  end
end
