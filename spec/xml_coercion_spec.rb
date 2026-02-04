# frozen_string_literal: true

RSpec.describe OpenapiFirst::XmlCoercion do
  describe '.xml_content_type?' do
    it 'returns true for application/xml' do
      expect(described_class.xml_content_type?('application/xml')).to be true
    end

    it 'returns true for text/xml' do
      expect(described_class.xml_content_type?('text/xml')).to be true
    end

    it 'returns true for application/xml with charset' do
      expect(described_class.xml_content_type?('application/xml; charset=utf-8')).to be true
    end

    it 'returns true for text/xml with charset' do
      expect(described_class.xml_content_type?('text/xml; charset=utf-8')).to be true
    end

    it 'returns false for application/json' do
      expect(described_class.xml_content_type?('application/json')).to be false
    end

    it 'returns false for nil' do
      expect(described_class.xml_content_type?(nil)).to be false
    end

    it 'returns false for empty string' do
      expect(described_class.xml_content_type?('')).to be false
    end

    it 'returns false for text/html' do
      expect(described_class.xml_content_type?('text/html')).to be false
    end
  end

  describe '.coerce_types' do
    context 'when schema has no properties' do
      it 'returns data unchanged' do
        data = { 'key' => 'value' }
        schema = {}
        expect(described_class.coerce_types(data, schema)).to eq(data)
      end
    end

    context 'with simple type coercion' do
      let(:schema) do
        {
          'properties' => {
            'age' => { 'type' => 'integer' },
            'price' => { 'type' => 'number' },
            'active' => { 'type' => 'boolean' },
            'name' => { 'type' => 'string' }
          }
        }
      end

      it 'coerces integer properties' do
        data = { 'age' => '42', 'name' => 'John' }
        result = described_class.coerce_types(data, schema)
        expect(result['age']).to eq(42)
      end

      it 'coerces number properties' do
        data = { 'price' => '19.99' }
        result = described_class.coerce_types(data, schema)
        expect(result['price']).to eq(19.99)
      end

      it 'coerces boolean properties' do
        data = { 'active' => 'true' }
        result = described_class.coerce_types(data, schema)
        expect(result['active']).to be true
      end

      it 'preserves string properties' do
        data = { 'name' => 'John' }
        result = described_class.coerce_types(data, schema)
        expect(result['name']).to eq('John')
      end

      it 'preserves keys not in schema' do
        data = { 'age' => '42', 'unknown' => 'value' }
        result = described_class.coerce_types(data, schema)
        expect(result['unknown']).to eq('value')
      end

      it 'only processes keys present in data' do
        data = { 'age' => '42' }
        result = described_class.coerce_types(data, schema)
        expect(result).not_to have_key('price')
      end
    end

    context 'with nested objects' do
      let(:schema) do
        {
          'properties' => {
            'user' => {
              'type' => 'object',
              'properties' => {
                'age' => { 'type' => 'integer' },
                'name' => { 'type' => 'string' }
              }
            }
          }
        }
      end

      it 'recursively coerces nested object properties' do
        data = { 'user' => { 'age' => '30', 'name' => 'Alice' } }
        result = described_class.coerce_types(data, schema)
        expect(result['user']['age']).to eq(30)
        expect(result['user']['name']).to eq('Alice')
      end

      it 'does not coerce nested objects when value is not a hash' do
        data = { 'user' => 'not_a_hash' }
        result = described_class.coerce_types(data, schema)
        expect(result['user']).to eq('not_a_hash')
      end
    end

    context 'with arrays' do
      let(:schema) do
        {
          'properties' => {
            'ids' => {
              'type' => 'array',
              'items' => { 'type' => 'integer' }
            }
          }
        }
      end

      it 'coerces array items' do
        data = { 'ids' => %w[1 2 3] }
        result = described_class.coerce_types(data, schema)
        expect(result['ids']).to eq([1, 2, 3])
      end

      it 'handles empty arrays' do
        data = { 'ids' => [] }
        result = described_class.coerce_types(data, schema)
        expect(result['ids']).to eq([])
      end
    end

    context 'with XML quirk - single item as hash instead of array' do
      let(:schema) do
        {
          'properties' => {
            'items' => {
              'type' => 'array',
              'items' => {
                'type' => 'object',
                'properties' => {
                  'id' => { 'type' => 'integer' }
                }
              }
            }
          }
        }
      end

      it 'converts single hash to array with coerced item' do
        data = { 'items' => { 'id' => '123' } }
        result = described_class.coerce_types(data, schema)
        expect(result['items']).to be_an(Array)
        expect(result['items'].size).to eq(1)
        expect(result['items'][0]['id']).to eq(123)
      end
    end

    context 'with arrays of objects' do
      let(:schema) do
        {
          'properties' => {
            'users' => {
              'type' => 'array',
              'items' => {
                'type' => 'object',
                'properties' => {
                  'age' => { 'type' => 'integer' },
                  'active' => { 'type' => 'boolean' }
                }
              }
            }
          }
        }
      end

      it 'coerces properties in array items' do
        data = { 'users' => [{ 'age' => '25', 'active' => 'true' }, { 'age' => '30', 'active' => 'false' }] }
        result = described_class.coerce_types(data, schema)
        expect(result['users'][0]['age']).to eq(25)
        expect(result['users'][0]['active']).to be true
        expect(result['users'][1]['age']).to eq(30)
        expect(result['users'][1]['active']).to be false
      end
    end

    context 'with oneOf schema' do
      let(:schema) do
        {
          'properties' => {
            'data' => {
              'oneOf' => [
                {
                  'type' => 'object',
                  'properties' => { 'id' => { 'type' => 'integer' } }
                },
                {
                  'type' => 'array',
                  'items' => {
                    'type' => 'object',
                    'properties' => { 'id' => { 'type' => 'integer' } }
                  }
                }
              ]
            }
          }
        }
      end

      it 'coerces hash value using object schema' do
        data = { 'data' => { 'id' => '42' } }
        result = described_class.coerce_types(data, schema)
        expect(result['data']['id']).to eq(42)
      end

      it 'coerces array value using array schema' do
        data = { 'data' => [{ 'id' => '1' }, { 'id' => '2' }] }
        result = described_class.coerce_types(data, schema)
        expect(result['data'][0]['id']).to eq(1)
        expect(result['data'][1]['id']).to eq(2)
      end
    end

    context 'with anyOf schema' do
      let(:schema) do
        {
          'properties' => {
            'value' => {
              'anyOf' => [
                { 'type' => 'object', 'properties' => { 'count' => { 'type' => 'integer' } } },
                { 'type' => 'array', 'items' => { 'type' => 'integer' } }
              ]
            }
          }
        }
      end

      it 'coerces hash value' do
        data = { 'value' => { 'count' => '10' } }
        result = described_class.coerce_types(data, schema)
        expect(result['value']['count']).to eq(10)
      end

      it 'coerces array value' do
        data = { 'value' => %w[5 10] }
        result = described_class.coerce_types(data, schema)
        expect(result['value']).to eq([5, 10])
      end
    end

    context 'with allOf schema' do
      # allOf means the value must satisfy ALL schemas simultaneously
      # This is typically used to combine properties from multiple schemas
      let(:schema) do
        {
          'properties' => {
            'user' => {
              'allOf' => [
                {
                  'type' => 'object',
                  'properties' => {
                    'id' => { 'type' => 'integer' },
                    'name' => { 'type' => 'string' }
                  }
                },
                {
                  'type' => 'object',
                  'properties' => {
                    'active' => { 'type' => 'boolean' },
                    'age' => { 'type' => 'integer' }
                  }
                }
              ]
            }
          }
        }
      end

      it 'merges properties from all schemas and coerces them' do
        data = {
          'user' => {
            'id' => '123',
            'name' => 'Alice',
            'active' => 'true',
            'age' => '30'
          }
        }
        result = described_class.coerce_types(data, schema)

        # All properties from both schemas should be coerced
        expect(result['user']['id']).to eq(123)
        expect(result['user']['name']).to eq('Alice')
        expect(result['user']['active']).to be true
        expect(result['user']['age']).to eq(30)
      end

      it 'handles partial data with properties from first schema' do
        data = { 'user' => { 'id' => '99', 'name' => 'Bob' } }
        result = described_class.coerce_types(data, schema)

        expect(result['user']['id']).to eq(99)
        expect(result['user']['name']).to eq('Bob')
      end

      it 'handles partial data with properties from second schema' do
        data = { 'user' => { 'active' => 'false', 'age' => '25' } }
        result = described_class.coerce_types(data, schema)

        expect(result['user']['active']).to be false
        expect(result['user']['age']).to eq(25)
      end

      context 'with three schemas in allOf' do
        let(:schema) do
          {
            'properties' => {
              'product' => {
                'allOf' => [
                  {
                    'type' => 'object',
                    'properties' => { 'id' => { 'type' => 'integer' } }
                  },
                  {
                    'type' => 'object',
                    'properties' => { 'price' => { 'type' => 'number' } }
                  },
                  {
                    'type' => 'object',
                    'properties' => { 'inStock' => { 'type' => 'boolean' } }
                  }
                ]
              }
            }
          }
        end

        it 'merges properties from all three schemas' do
          data = {
            'product' => {
              'id' => '456',
              'price' => '29.99',
              'inStock' => 'true'
            }
          }
          result = described_class.coerce_types(data, schema)

          expect(result['product']['id']).to eq(456)
          expect(result['product']['price']).to eq(29.99)
          expect(result['product']['inStock']).to be true
        end
      end
    end

    context 'with complex nested structures' do
      let(:schema) do
        {
          'properties' => {
            'company' => {
              'type' => 'object',
              'properties' => {
                'name' => { 'type' => 'string' },
                'employees' => {
                  'type' => 'array',
                  'items' => {
                    'type' => 'object',
                    'properties' => {
                      'id' => { 'type' => 'integer' },
                      'active' => { 'type' => 'boolean' }
                    }
                  }
                }
              }
            }
          }
        }
      end

      it 'coerces deeply nested structures' do
        data = {
          'company' => {
            'name' => 'Acme',
            'employees' => [
              { 'id' => '1', 'active' => 'true' },
              { 'id' => '2', 'active' => 'false' }
            ]
          }
        }
        result = described_class.coerce_types(data, schema)
        expect(result['company']['name']).to eq('Acme')
        expect(result['company']['employees'][0]['id']).to eq(1)
        expect(result['company']['employees'][0]['active']).to be true
        expect(result['company']['employees'][1]['id']).to eq(2)
        expect(result['company']['employees'][1]['active']).to be false
      end
    end
  end
end
