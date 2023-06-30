TIER_VALUES = ['A', 'B', 'C'].freeze

class ZipCodeEndpoint
  class << self
    attr_accessor :zip_code, :radius, :units
    attr_reader :conn
    def initialize
      @conn = Faraday.new(
        url: "https://www.zipcodeapi.com/rest/#{ENV['ZIP_CODE_API_KEY']}",
        headers: { 'Content-Type' => 'application/json' }
      )
    end
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
      response = @conn.post("/radius.json/#{@zip_code}/#{@radius}/#{@units}")
      return nil unless response.success?

      JSON.parse(response.body)
    end

    def extract_zip_codes_from_db(zipcodes)
      PartnerClinic.where('zipcode IN (?)', zipcodes).where('tier IN (?)', TIER_VALUES).order('tier ASC')
    end

    def sort_extracted_zips_from_db_by_distance(zip_codes_with_distance, zip_codes_from_db)
      quicksort(zip_codes_from_db, 0, zip_codes_from_db.length - 1, zip_codes_with_distance)
    end

    def quicksort(zip_codes, low, high, zip_codes_with_distance)
      if low < high
        pivot_index = partition(zip_codes, low, high, zip_codes_with_distance)
        quicksort(zip_codes, low, pivot_index - 1, zip_codes_with_distance)
        quicksort(zip_codes, pivot_index + 1, high, zip_codes_with_distance)
      end
    end
    
    def partition(zip_codes, low, high, zip_codes_with_distance)
      pivot = zip_codes[high]
      i = low - 1
    
      (low..high - 1).each do |j|
        if compare_zip_tier(zip_codes[j], pivot) || (zip_codes[j].tier == pivot.tier && compare_zip_distances(zip_codes[j].zipcode, pivot.zipcode, zip_codes_with_distance))
          i += 1
          zip_codes[i], zip_codes[j] = zip_codes[j], zip_codes[i]
        end
      end
      
      zip_codes[i+1], zip_codes[high] = zip_codes[high], zip_codes[i+1]
      i + 1
    end

    def compare_zip_tier(zip1, zip2)
      TIER_VALUES.index(zip1.tier) < TIER_VALUES.index(zip2.tier)
    end

    def compare_zip_distances(zip1, zip2, zip_codes_with_distance)
      # use zip_codes as keys to get the distances from zip_codes_with_distance
      zip_codes_with_distance[zip1] > zip_codes_with_distance[zip2]
    end
  end
end