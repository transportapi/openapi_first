# frozen_string_literal: true

RSpec.describe OpenapiFirst::TypeCoercion do
  describe '.coerce_value' do
    context 'when schema type is boolean' do
      let(:schema) { { 'type' => 'boolean' } }

      it 'converts "true" string to true boolean' do
        expect(described_class.coerce_value('true', schema)).to be true
      end

      it 'converts "false" string to false boolean' do
        expect(described_class.coerce_value('false', schema)).to be false
      end

      it 'returns original value for non-boolean strings' do
        expect(described_class.coerce_value('not_a_boolean', schema)).to eq('not_a_boolean')
      end

      it 'returns original value for nil' do
        expect(described_class.coerce_value(nil, schema)).to be_nil
      end

      it 'returns original value for uppercase value' do
        expect(described_class.coerce_value('FALSE', schema)).to eq('FALSE')
      end
    end

    context 'when schema type is integer' do
      let(:schema) { { 'type' => 'integer' } }

      it 'converts valid integer string to integer' do
        expect(described_class.coerce_value('42', schema)).to eq(42)
      end

      it 'converts negative integer string to integer' do
        expect(described_class.coerce_value('-42', schema)).to eq(-42)
      end

      it 'converts zero string to integer' do
        expect(described_class.coerce_value('0', schema)).to eq(0)
      end

      it 'returns original value for invalid integer strings' do
        expect(described_class.coerce_value('not_an_integer', schema)).to eq('not_an_integer')
      end

      it 'returns original value for float strings' do
        expect(described_class.coerce_value('42.5', schema)).to eq('42.5')
      end

      it 'returns original value for empty string' do
        expect(described_class.coerce_value('', schema)).to eq('')
      end

      it 'returns original value when ArgumentError is raised' do
        expect(described_class.coerce_value('12abc', schema)).to eq('12abc')
      end
    end

    context 'when schema type is number' do
      let(:schema) { { 'type' => 'number' } }

      it 'converts valid float string to float' do
        expect(described_class.coerce_value('42.5', schema)).to eq(42.5)
      end

      it 'converts integer string to float' do
        expect(described_class.coerce_value('42', schema)).to eq(42.0)
      end

      it 'converts negative float string to float' do
        expect(described_class.coerce_value('-42.5', schema)).to eq(-42.5)
      end

      it 'converts zero string to float' do
        expect(described_class.coerce_value('0', schema)).to eq(0.0)
      end

      it 'returns original value for invalid number strings' do
        expect(described_class.coerce_value('not_a_number', schema)).to eq('not_a_number')
      end

      it 'returns original value for empty string' do
        expect(described_class.coerce_value('', schema)).to eq('')
      end

      it 'returns original value when ArgumentError is raised' do
        expect(described_class.coerce_value('12.5abc', schema)).to eq('12.5abc')
      end
    end

    context 'when schema type is string or other' do
      let(:schema) { { 'type' => 'string' } }

      it 'returns original value without coercion' do
        expect(described_class.coerce_value('some_string', schema)).to eq('some_string')
      end

      it 'returns numeric string as-is' do
        expect(described_class.coerce_value('123', schema)).to eq('123')
      end
    end

    context 'when schema type is nil or missing' do
      let(:schema) { {} }

      it 'returns original value without coercion' do
        expect(described_class.coerce_value('value', schema)).to eq('value')
      end
    end
  end
end
