# frozen_string_literal: true

module OpenapiFirst
  module ContentType
    module_function

    def xml?(content_type)
      matches?(content_type, 'application/xml', 'text/xml')
    end

    def form_encoded?(content_type)
      matches?(content_type, 'application/x-www-form-urlencoded')
    end

    def plain_text?(content_type)
      matches?(content_type, 'text/plain')
    end

    def matches?(content_type, *media_types)
      return false unless content_type

      media_type = content_type.split(';').first&.strip&.downcase
      media_types.include?(media_type)
    end

    private_class_method :matches?
  end
end
