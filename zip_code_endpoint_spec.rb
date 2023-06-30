require 'rspec'
#require 'spec_helper'
require_relative 'zip_code_endpoint'

RSpec.describe ZipCodeEndpoint do
  describe '.get_zip_in_radius' do
    let(:zipcode) { '12345' }
    let(:radius) { 10 }
    let(:units) { 'mile' }
    let(:zip_data) { { 'zip_codes' => [], 'zip_codes_with_distance' => {} } }
    let(:zipcodes) { ['12345', '54321', '67890'] }
    let(:zipcodes_with_distance) { { '54321' => 5, '67890' => 8, '12345' => 3 } }
    let(:sorted_zips) { [
      double('ZipCode', name: 'Name1', address: 'Address1', city: 'City1', state: 'State1', zipcode: '54321', tier: 'A', contact_email: 'email1@example.com', contact_name: 'Name1'),
      double('ZipCode', name: 'Name2', address: 'Address2', city: 'City2', state: 'State2', zipcode: '67890', tier: 'B', contact_email: 'email2@example.com', contact_name: 'Name2'),
      double('ZipCode', name: 'Name3', address: 'Address3', city: 'City3', state: 'State3', zipcode: '12345', tier: 'C', contact_email: 'email3@example.com', contact_name: 'Name3')
    ] }
    let(:formatted_response) { [
      { name: 'Name1', address: 'Address1', city: 'City1', state: 'State1', distance: 5, tier: 'A', contact_email: 'email1@example.com', contact_name: 'Name1' },
      { name: 'Name2', address: 'Address2', city: 'City2', state: 'State2', distance: 8, tier: 'B', contact_email: 'email2@example.com', contact_name: 'Name2' },
      { name: 'Name3', address: 'Address3', city: 'City3', state: 'State3', distance: 3, tier: 'C', contact_email: 'email3@example.com', contact_name: 'Name3' }
    ] }

    before do
      allow(ZipCodeEndpoint).to receive(:call_zip_codes_api).and_return(zip_data)
      allow(ZipCodeEndpoint).to receive(:extract_zip_codes_from_db).and_return(sorted_zips)
      allow(ZipCodeEndpoint).to receive(:sort_extracted_zips_from_db_by_distance)
      allow(ZipCodeEndpoint).to receive(:format_response).and_return(:formatted_response)
    end

    it 'calls the zip codes API with the correct parameters' do
      expect(ZipCodeEndpoint).to receive(:call_zip_codes_api).with(zipcode, radius, units)
      ZipCodeEndpoint.get_zip_in_radius(zipcode, radius, units)
    end

    context 'when zip data is nil' do
      let(:zip_data) { nil }

      it 'returns an empty array' do
        expect(ZipCodeEndpoint.get_zip_in_radius(zipcode, radius, units)).to eq([])
      end
    end

    context 'when zip data is not nil' do
      before do
        allow(zip_data['zip_codes']).to receive(:each).and_yield({ 
          'zip_code' => '12345', 'distance' => 3 
        }).and_yield({ 
          'zip_code' => '54321', 'distance' => 5 
        }).and_yield({ 
          'zip_code' => '67890', 
          'distance' => 8 
        })
      end

      it 'extracts zip codes from the API response' do
        expect(ZipCodeEndpoint).to receive(:extract_zip_codes_from_db).with(zipcodes).and_return(sorted_zips)
        ZipCodeEndpoint.get_zip_in_radius(zipcode, radius, units)
      end

      it 'sorts the extracted zip codes by distance' do
        expect(ZipCodeEndpoint).to receive(:sort_extracted_zips_from_db_by_distance).with(zipcodes_with_distance, sorted_zips)
        ZipCodeEndpoint.get_zip_in_radius(zipcode, radius, units)
      end

      it 'formats the response' do
        expect(ZipCodeEndpoint).to receive(:format_response).with(sorted_zips, zipcodes_with_distance)
        ZipCodeEndpoint.get_zip_in_radius(zipcode, radius, units)
      end

      it 'returns the formatted response' do
        expect(ZipCodeEndpoint.get_zip_in_radius(zipcode, radius, units)).to eq(:formatted_response)
      end
    end
  end
end