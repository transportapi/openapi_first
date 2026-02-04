# frozen_string_literal: true

require_relative 'spec_helper'
require 'rack'
require 'openapi_first/response_validator'

RSpec.describe OpenapiFirst::ResponseValidator do
  let(:spec) { './spec/data/petstore.yaml' }

  let(:subject) do
    described_class.new(spec)
  end

  let(:request) do
    env = Rack::MockRequest.env_for('/pets')
    Rack::Request.new(env)
  end

  let(:headers) { { Rack::CONTENT_TYPE => 'application/json' } }

  describe 'valid response' do
    it 'raises nothing' do
      response_body = json_dump([
                                  { id: 42, name: 'hans' },
                                  { id: 2, name: 'Voldemort' }
                                ])
      response = Rack::MockResponse.new(200, headers, response_body)
      expect { subject.validate(request, response) }.not_to raise_error
    end

    it 'falls back to the default' do
      response_body = JSON.dump(code: 422, message: 'Not good!')
      response = Rack::MockResponse.new(422, headers, response_body)
      expect { subject.validate(request, response) }.not_to raise_error
    end

    it 'returns no errors on additional, not required properties' do
      response_body = json_dump([{ id: 42, name: 'hans', something: 'else' }])
      response = Rack::MockResponse.new(200, headers, response_body)
      expect { subject.validate(request, response) }.not_to raise_error
    end

    it 'returns no errors if OAS file has no content' do
      expect_any_instance_of(OpenapiFirst::Operation).to receive(:response_for) { {} }
      response = Rack::MockResponse.new(200, headers, 'body')
      expect { subject.validate(request, response) }.not_to raise_error
    end

    it 'returns no errors if OAS file has no response_for schema specified' do
      empty_content = { 'application/json' => {} }
      expect_any_instance_of(OpenapiFirst::Operation)
        .to receive(:response_for) { { 'content' => empty_content } }
      response = Rack::MockResponse.new(200, headers, 'body')
      expect { subject.validate(request, response) }.not_to raise_error
    end
  end

  describe 'invalid response' do
    it 'fails on unknown http method' do
      request = begin
        env = Rack::MockRequest.env_for('/pets', method: 'PATCH')
        Rack::Request.new(env)
      end
      response_body = json_dump([{ id: 'string', name: 'hans' }])
      response = Rack::MockResponse.new(200, headers, response_body)
      expect do
        subject.validate(request, response)
      end.to raise_error OpenapiFirst::NotFoundError
    end

    it 'fails on unknown status' do
      env = Rack::MockRequest.env_for('/pets/1')
      request = Rack::Request.new(env)
      response_body = json_dump([{ id: 2, name: 'Voldemort' }])
      response = Rack::MockResponse.new(201, headers, response_body)
      expect do
        subject.validate(request, response)
      end.to raise_error OpenapiFirst::ResponseInvalid
    end

    it 'fails on wrong content type' do
      response_body = json_dump([{ id: 2, name: 'Voldemort' }])
      headers = { Rack::CONTENT_TYPE => 'application/xml' }
      response = Rack::MockResponse.new(200, headers, response_body)
      expect do
        subject.validate(request, response)
      end.to raise_error OpenapiFirst::ResponseInvalid
    end

    it 'returns errors on missing property' do
      response_body = json_dump([{ id: 42 }, { id: 2, name: 'Voldemort' }])
      response = Rack::MockResponse.new(200, headers, response_body)
      expect do
        subject.validate(request, response)
      end.to raise_error OpenapiFirst::ResponseInvalid
    end

    it 'returns errors on wrong property type' do
      response_body = json_dump([{ id: 'string', name: 'hans' }])
      response = Rack::MockResponse.new(200, headers, response_body)
      expect do
        subject.validate(request, response)
      end.to raise_error OpenapiFirst::ResponseInvalid
    end
  end

  describe 'XML response validation' do
    let(:xml_spec) { './spec/data/petstore-xml.yaml' }

    let(:xml_validator) do
      described_class.new(xml_spec)
    end

    let(:xml_headers) { { Rack::CONTENT_TYPE => 'application/xml' } }

    let(:xml_request) do
      env = Rack::MockRequest.env_for('/pets', method: 'GET')
      Rack::Request.new(env)
    end

    describe 'valid XML response' do
      it 'validates valid XML response' do
        response_body = <<~XML
          <pets>
            <pet status="available">
              <id>42</id>
              <name>hans</name>
            </pet>
            <pet status="sold">
              <id>2</id>
              <name>Voldemort</name>
            </pet>
          </pets>
        XML
        response = Rack::MockResponse.new(200, xml_headers, response_body)
        expect { xml_validator.validate(xml_request, response) }.not_to raise_error
      end

      it 'accepts additional XML elements' do
        response_body = <<~XML
          <pets>
            <pet status="pending">
              <id>42</id>
              <name>hans</name>
              <tag>extra</tag>
            </pet>
          </pets>
        XML
        response = Rack::MockResponse.new(200, xml_headers, response_body)
        expect { xml_validator.validate(xml_request, response) }.not_to raise_error
      end
    end

    describe 'invalid XML response' do
      it 'fails on missing required XML elements' do
        response_body = <<~XML
          <pets>
            <pet status="available">
              <id>42</id>
            </pet>
          </pets>
        XML
        response = Rack::MockResponse.new(200, xml_headers, response_body)
        expect do
          xml_validator.validate(xml_request, response)
        end.to raise_error OpenapiFirst::ResponseInvalid
      end

      it 'fails on unknown status code' do
        response_body = <<~XML
          <pets>
            <pet status="available">
              <id>42</id>
              <name>hans</name>
            </pet>
          </pets>
        XML
        response = Rack::MockResponse.new(204, xml_headers, response_body)
        expect do
          xml_validator.validate(xml_request, response)
        end.to raise_error OpenapiFirst::ResponseInvalid
      end
    end

    describe 'XML attribute validation' do
      it 'validates XML attributes (status)' do
        response_body = <<~XML
          <pets>
            <pet status="available">
              <id>42</id>
              <name>Fluffy</name>
            </pet>
          </pets>
        XML
        response = Rack::MockResponse.new(200, xml_headers, response_body)
        expect { xml_validator.validate(xml_request, response) }.not_to raise_error
      end

      it 'fails when required attribute is missing' do
        response_body = <<~XML
          <pets>
            <pet>
              <id>42</id>
              <name>Fluffy</name>
            </pet>
          </pets>
        XML
        response = Rack::MockResponse.new(200, xml_headers, response_body)
        expect do
          xml_validator.validate(xml_request, response)
        end.to raise_error OpenapiFirst::ResponseInvalid
      end

      it 'fails when attribute has invalid enum value' do
        response_body = <<~XML
          <pets>
            <pet status="reserved">
              <id>42</id>
              <name>Fluffy</name>
            </pet>
          </pets>
        XML
        response = Rack::MockResponse.new(200, xml_headers, response_body)
        expect do
          xml_validator.validate(xml_request, response)
        end.to raise_error OpenapiFirst::ResponseInvalid
      end
    end
  end
end
