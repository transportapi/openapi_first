# frozen_string_literal: true

module OpenapiFirst
  module ContentType
    module_function

    def json?(content_type)
      return false unless content_type

      media_type = content_type.split(';').first&.strip
      media_type == 'application/json'
    end

    def xml?(content_type)
      return false unless content_type

      media_type = content_type.split(';').first&.strip
      %w[application/xml text/xml].include?(media_type)
    end

    def form_encoded?(content_type)
      return false unless content_type

      media_type = content_type.split(';').first&.strip
      media_type == 'application/x-www-form-urlencoded'
    end

    def plain_text?(content_type)
      return false unless content_type

      media_type = content_type.split(';').first&.strip
      media_type == 'text/plain'
    end
  end
end
