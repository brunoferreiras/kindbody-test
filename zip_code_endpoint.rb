# This constant is an array of strings that represents the different tiers. It is frozen to prevent modification.
TIER_VALUES = ['A', 'B', 'C'].freeze

=begin
This class represents an endpoint for retrieving zip codes within a certain radius. It has the following class variables:
- `zip_code`: The starting zip code
- `radius`: The radius within which to search for zip codes
- `units`: The units of measurement for the radius
=end
class ZipCodeEndpoint
  class << self
    attr_accessor :zip_code, :radius, :units
    attr_reader :conn
    # This method is the constructor for the ZipCodeEndpoint class. It initializes the `conn` instance variable with a new instance of the Faraday class, which is used to make HTTP requests.
    def initialize
      @conn = Faraday.new(
        url: "https://www.zipcodeapi.com/rest/#{ENV['ZIP_CODE_API_KEY']}",
        headers: { 'Content-Type' => 'application/json' }
      )
    end
    # This method retrieves a list of zip codes within the specified radius from the starting zip code. It takes three parameters: `zipcode`, `radius`, and `units` (optional, defaults to 'mile').
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

    # This private method takes two parameters: `sorted_zips` (an array of zip codes) and `zip_codes_with_distance` (a hash mapping zip codes to distances). It formats the zip codes and distances into a response object with the following attributes: `name`, `address`, `city`, `state`, `distance`, `tier`, `contact_email`, and `contact_name`.
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

    # This private method retrieves the zip codes and distances from the API. It calls the `call_zip_codes_api` method to make a POST request to the API and parses the response. It returns a hash with two keys: `zip_codes` (an array of zip codes) and `zip_codes_with_distance` (a hash mapping zip codes to distances).
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

    # This private method makes a POST request to the API to retrieve the zip codes and distances within the specified radius from the starting zip code. It uses the `conn` instance variable to make the request and returns the parsed response body as a JSON object.
    def call_zip_codes_api()
      response = @conn.post("/radius.json/#{@zip_code}/#{@radius}/#{@units}")
      return nil unless response.success?

      JSON.parse(response.body)
    end

    # This private method retrieves the zip codes from the database that match the zip codes returned from the API. It takes one parameter: `zipcodes` (an array of zip codes). It queries the PartnerClinic model to find zip codes that are in the `zipcodes` array and have a tier value in the `TIER_VALUES` constant. It orders the results by tier in ascending order and returns the result collection.
    def extract_zip_codes_from_db(zipcodes)
      PartnerClinic.where('zipcode IN (?)', zipcodes).where('tier IN (?)', TIER_VALUES).order('tier ASC')
    end

    # This private method sorts the zip codes from the database by distance. It takes two parameters: `zip_codes_with_distance` (a hash mapping zip codes to distances) and `zip_codes_from_db` (an array of zip codes from the database). It calls the `quicksort` method to perform the sorting.
    def sort_extracted_zips_from_db_by_distance(zip_codes_with_distance, zip_codes_from_db)
      quicksort(zip_codes_from_db, 0, zip_codes_from_db.length - 1, zip_codes_with_distance)
    end

    # This private method implements the quicksort algorithm to sort the zip codes by distance. It takes four parameters: `zip_codes` (an array of zip codes), `low` (the starting index), `high` (the ending index), and `zip_codes_with_distance` (a hash mapping zip codes to distances). It recursively partitions the array and sorts the partitions.
    def quicksort(zip_codes, low, high, zip_codes_with_distance)
      if low < high
        pivot_index = partition(zip_codes, low, high, zip_codes_with_distance)
        quicksort(zip_codes, low, pivot_index - 1, zip_codes_with_distance)
        quicksort(zip_codes, pivot_index + 1, high, zip_codes_with_distance)
      end
    end

    # This private method partitions the zip codes array for the quicksort algorithm. It takes four parameters: `zip_codes` (an array of zip codes), `low` (the starting index), `high` (the ending index), and `zip_codes_with_distance` (a hash mapping zip codes to distances). It selects a pivot element and rearranges the array so that all elements less than the pivot come before it and all elements greater than the pivot come after it. It returns the index of the pivot element.
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

    # This private method compares the tier values of two zip codes. It takes two parameters: `zip1` and `zip2` (zip code objects). It uses the `TIER_VALUES` constant to determine the order of the tiers and returns true if `zip1` has a lower tier than `zip2`.
    def compare_zip_tier(zip1, zip2)
      TIER_VALUES.index(zip1.tier) < TIER_VALUES.index(zip2.tier)
    end

    # This private method compares the distances of two zip codes. It takes three parameters: `zip1` and `zip2` (zip codes as strings) and `zip_codes_with_distance` (a hash mapping zip codes to distances). It uses the `zip_codes_with_distance` hash to retrieve the distances for the zip codes and returns true if the distance of `zip1` is greater than the distance of `zip2`.
    def compare_zip_distances(zip1, zip2, zip_codes_with_distance)
      zip_codes_with_distance[zip1] > zip_codes_with_distance[zip2]
    end
  end
end