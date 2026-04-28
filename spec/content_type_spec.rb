# frozen_string_literal: true

RSpec.describe OpenapiFirst::ContentType do
  describe '.xml?' do
    it 'returns true for application/xml' do
      expect(described_class.xml?('application/xml')).to be true
    end

    it 'returns true for text/xml' do
      expect(described_class.xml?('text/xml')).to be true
    end

    it 'returns true for TEXT/XML (i.e. is case insensitive)' do
      expect(described_class.xml?('text/xml')).to be true
    end

    it 'returns true for application/xml with charset' do
      expect(described_class.xml?('application/xml; charset=utf-8')).to be true
    end

    it 'returns false for application/json' do
      expect(described_class.xml?('application/json')).to be false
    end

    it 'returns false for nil' do
      expect(described_class.xml?(nil)).to be false
    end
  end

  describe '.form_encoded?' do
    it 'returns true for application/x-www-form-urlencoded' do
      expect(described_class.form_encoded?('application/x-www-form-urlencoded')).to be true
    end

    it 'returns true for application/x-www-form-urlencoded with charset' do
      expect(described_class.form_encoded?('application/x-www-form-urlencoded; charset=utf-8')).to be true
    end

    it 'returns true for Application/x-www-form-urlencoded (i.e. is case insensitive)' do
      expect(described_class.form_encoded?('Application/x-www-form-urlencoded')).to be true
    end

    it 'returns false for application/json' do
      expect(described_class.form_encoded?('application/json')).to be false
    end

    it 'returns false for nil' do
      expect(described_class.form_encoded?(nil)).to be false
    end
  end

  describe '.plain_text?' do
    it 'returns true for text/plain' do
      expect(described_class.plain_text?('text/plain')).to be true
    end

    it 'returns true for text/plain with charset' do
      expect(described_class.plain_text?('text/plain; charset=utf-8')).to be true
    end

    it 'returns true for Text/Plain (i.e. is case insensitive)' do
      expect(described_class.plain_text?('Text/Plain')).to be true
    end

    it 'returns false for application/json' do
      expect(described_class.plain_text?('application/json')).to be false
    end

    it 'returns false for nil' do
      expect(described_class.plain_text?(nil)).to be false
    end
  end
end
