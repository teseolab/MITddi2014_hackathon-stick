require 'curb'
require 'eventmachine'
require 'temboo'
require 'Library/Google'
require 'geo-distance'
require 'sqlite3'

module Stick
  module Runner

    LO = 3
    HI = 4000

    def self.run!
      # Instantiate the Choreo, using a previously instantiated TembooSession object, eg:
      session = TembooSession.new("TEMBOO_USERNAME", "myFirstApp", "TEMBOO_KEY")
      geocodeByAddressChoreo = Google::Geocoding::GeocodeByAddress.new(session)

      @db_hit = -> do
        @db = SQLite3::Database.new "dev.sqlite3"
        @db.execute( "select address, position from tags where id = 1" ) do |row|

          address = row[0]
          position = row[1]

          geocodeByAddressInputs = geocodeByAddressChoreo.new_input_set()
          # Set inputs
          geocodeByAddressInputs.set_Address(address);
          # Execute Choreo
          geocodeByAddressResults = geocodeByAddressChoreo.execute(geocodeByAddressInputs)
          lat_add = geocodeByAddressResults.get_Latitude
          long_add = geocodeByAddressResults.get_Longitude

          geocodeByAddressInputs = geocodeByAddressChoreo.new_input_set()
          # Set inputs
          geocodeByAddressInputs.set_Address(position);
          # Execute Choreo
          geocodeByAddressResults = geocodeByAddressChoreo.execute(geocodeByAddressInputs)
          lat_pos = geocodeByAddressResults.get_Latitude
          long_pos = geocodeByAddressResults.get_Longitude
          dist = GeoDistance::Haversine.distance( lat_add.to_f, long_add.to_f, lat_pos.to_f, long_pos.to_f )

          puts dist.miles
          d = dist.miles.number

          if d <= LO 
            r = 0
            g = 255
            b = 0
          elsif d >= 4000
            r = 255
            g = 0
            b = 0
          else
            norm_dist = (d - LO) / (HI - LO).to_f
            r = (255 * norm_dist).ceil
            g = 255 - r
            b = 0
          end
          
          # puts "#{r}-#{g}-#{b}"
          Curl.get("http://192.168.0.100/C?r=#{r},g=#{g},b=#{b}")

        end
        @db.close
      end

      EM.run do
        
        # EM.add_timer(200) do
        #   puts 'quitting'
        #   begin
        #     Curl.get("http://192.168.0.101/L")
        #   rescue Exception
        #   end
        #   EM.stop_event_loop
        # end
        EM.add_periodic_timer(3) do
          begin
            @db_hit.call
          rescue Exception
          end
          puts 'tick'
        end
      end

      
    end

  end
end