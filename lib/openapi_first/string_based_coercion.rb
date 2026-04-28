# frozen_string_literal: true

require_relative 'type_coercion'

module OpenapiFirst
  module StringBasedCoercion
    module_function

    def coercible_content_type?(content_type)
      ContentType.xml?(content_type) || ContentType.form_encoded?(content_type)
    end

    def coerce_types(data, schema)
      return data unless schema['properties']

      schema['properties'].each_with_object({}) do |(key, property_schema), result|
        next unless data.key?(key)

        value = data[key]

        # Check if this property has oneOf/anyOf/allOf
        result[key] = if property_schema['oneOf'] || property_schema['anyOf'] || property_schema['allOf']
                        coerce_with_combined_schemas(value, property_schema)
                      elsif property_schema['properties'] && value.is_a?(Hash)
                        # Nested object - recurse
                        coerce_types(value, property_schema)
                      elsif property_schema['type'] == 'array' && value.is_a?(Array)
                        # Array - coerce each item
                        coerce_array(value, property_schema)
                      elsif property_schema['type'] == 'array' && value.is_a?(Hash)
                        # XML quirk: Hash.from_xml parses a single child element as Hash instead of Array)
                        [coerce_item(value, property_schema['items'])]
                      else
                        # Simple value - coerce based on type
                        TypeCoercion.coerce_value(value, property_schema)
                      end
      end.merge(data.except(*schema['properties'].keys))
    end

    private_class_method def coerce_with_combined_schemas(value, schema)
      # Special handling for allOf - merge all schemas together
      if schema['allOf']
        schemas = schema['allOf']
        merged_properties = schemas.each_with_object({}) do |s, props|
          props.merge!(s['properties']) if s['properties']
        end
        merged_schema = { 'type' => 'object', 'properties' => merged_properties }
        return coerce_item(value, merged_schema)
      end

      # For oneOf/anyOf, pick the appropriate schema based on value type
      schemas = schema['oneOf'] || schema['anyOf']

      case value
      when Array
        array_schema = schemas.find { |s| s['type'] == 'array' }
        return coerce_array(value, array_schema) if array_schema
      when Hash
        object_schema = schemas.find { |s| s['type'] != 'array' }
        return coerce_item(value, object_schema) if object_schema
      end

      value
    end

    private_class_method def coerce_array(array, schema)
      return array unless schema['items']

      array.map do |item|
        coerce_item(item, schema['items'])
      end
    end

    private_class_method def coerce_item(item, schema)
      if schema['properties'] && item.is_a?(Hash)
        coerce_types(item, schema)
      else
        TypeCoercion.coerce_value(item, schema)
      end
    end
  end
end
