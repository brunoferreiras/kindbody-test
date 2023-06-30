TIER_VALUES = ['A', 'B', 'C'].freeze

class ZipCodeEndpoint
  class << self
    attr_accessor :zip_code, :radius, :units
    def get_zip_in_radius(zipcode, radius, units = 'mile')
      @zip_code = zipcode
      @radius = radius
      @units = units
      # 1. Get list of ZIP codes in radius from starting zip code point
      extracted_zips_from_api = extract_zip_codes_from_api()
      return [] unless extracted_zips_from_api

      # 2. find all ZIP codes in the DB that match the response, and sort by tier ASC
      extracted_zips_from_db = extract_zip_codes_from_db(extracted_zips_from_api['zip_codes']).to_a

      # 3. Sort ZIP codes in the same tier by distance
      sort_extracted_zips_from_db_by_distance(extracted_zips_from_api['zip_codes_with_distance'], extracted_zips_from_db)

      format_response(extracted_zips_from_db, extracted_zips_from_api['zip_codes_with_distance'])
    end

    private

    def format_response(sorted_zips, zip_codes_with_distance)
      sorted_zips.map do |item|
        {
          name: item.name,
          address: item.address,
          city: item.city,
          state: item.state,
          distance: zip_codes_with_distance[item.zipcode],
          tier: item.tier,
          contact_email: item.contact_email,
          contact_name: item.contact_name
        }
      end
    end

    def extract_zip_codes_from_api()
      zip_data = call_zip_codes_api(zip_code, radius, units)
      return nil unless zip_data

      zip_codes = []
      zip_codes_with_distance = {}

      zip_data['zip_codes'].each do |item|
        zip_codes << item['zip_code']
        zip_codes_with_distance[item['zip_code']] = item['distance']
      end
      
      { 'zip_codes' => zip_codes, 'zip_codes_with_distance' => zip_codes_with_distance }
    end

    def call_zip_codes_api()
      url = "https://www.zipcodeapi.com/rest/#{ENV['ZIP_CODE_API_KEY']}/radius.json/#{zip_code}/#{radius}/#{units}"
      zip_response = Faraday.send(:post, url)
      return nil unless zip_response.success?

      JSON.parse(zip_response.body)
    end

    def extract_zip_codes_from_db(zipcodes)
      PartnerClinic.where('zipcode IN (?)', zipcodes).where('tier IN (?)', TIER_VALUES).order('tier ASC')
    end

    def sort_extracted_zips_from_db_by_distance(zip_codes_with_distance, zip_codes_from_db)
      i = 0
      tier_marker_begin = 0
      while i < zip_codes_from_db.length
        if (i == zip_codes_from_db.length - 1) || (zip_codes_from_db[i + 1].tier != zip_codes_from_db[i].tier)
          (tier_marker_begin..i - 1).each do |j|
            (tier_marker_begin..(i - 1 - j + tier_marker_begin)).each do |k|
              if compare_zip_distances(zip_codes_from_db[k].zipcode, zip_codes_from_db[k + 1].zipcode, zip_codes_with_distance)
                swap_zip_codes(k, k + 1, zip_codes_from_db)
              end
            end
          end
          tier_marker_begin = i + 1
        end
        i += 1
      end
    end

    def compare_zip_distances(zip1, zip2, zip_codes_with_distance)
      # use zip_codes as keys to get the distances from zip_codes_with_distance
      zip_codes_with_distance[zip1] > zip_codes_with_distance[zip2]
    end

    def swap_zip_codes(index_src, index_dst, zip_codes)
      tmp = zip_codes[index_src]
      zip_codes[index_src] = zip_codes[index_dst]
      zip_codes[index_dst] = tmp
    end
  end
end