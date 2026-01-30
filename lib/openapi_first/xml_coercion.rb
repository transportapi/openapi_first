# frozen_string_literal: true

require_relative 'type_coercion'

module OpenapiFirst
  module XmlCoercion
    module_function

    def xml_content_type?(content_type)
      return false unless content_type

      media_type = content_type.split(';').first&.strip
      %w[application/xml text/xml].include?(media_type)
    end

    def coerce_types(data, schema)
      return data unless schema['properties']

      schema['properties'].each_with_object({}) do |(key, property_schema), result|
        next unless data.key?(key)

        value = data[key]

        # Check if this property has oneOf/anyOf/allOf
        result[key] = if property_schema['oneOf'] || property_schema['anyOf'] || property_schema['allOf']
                        coerce_with_one_of(value, property_schema)
                      elsif property_schema['properties'] && value.is_a?(Hash)
                        # Nested object - recurse
                        coerce_types(value, property_schema)
                      elsif property_schema['type'] == 'array' && value.is_a?(Array)
                        # Array - coerce each item
                        coerce_array(value, property_schema)
                      elsif property_schema['type'] == 'array' && value.is_a?(Hash)
                        # Single item that should be array (XML quirk from Hash.from_xml)
                        [coerce_item(value, property_schema['items'])]
                      else
                        # Simple value - coerce based on type
                        TypeCoercion.coerce_value(value, property_schema)
                      end
      end.merge(data.except(*schema['properties'].keys))
    end

    private_class_method def coerce_with_one_of(value, schema)
      schemas = schema['oneOf'] || schema['anyOf'] || schema['allOf']

      # For Hash (single item), try the first schema (should be the object schema)
      # For Array, try the second schema (should be the array schema)
      case value
      when Array
        array_schema = schemas.find { |s| s['type'] == 'array' }
        return coerce_array(value, array_schema) if array_schema
      when Hash
        object_schema = schemas.find { |s| s['type'] != 'array' }
        # Need to resolve $ref here - for now just try to coerce
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
