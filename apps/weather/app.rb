require 'open_weather'

class Weather

	@@name		= "Weather"
	@@version	= "1.0"
	@@description	= "This application provides a descriptive weather tile for the dashboard.  OpenWeatherMap is used and requires the \'open-weather\' gem on the server."

	def self.install_tables(db)
		db.execute "CREATE TABLE WeatherLocation(location TEXT);"
	end

	def self.remove_tables(db)
		db.execute("DROP TABLE WeatherLocation;")
	end

	def self.routes
		return [{
			:verb => "get",
			:url => "set_location/:id",
			:method => Weather.method(:set_location)
		}]
	end

	def self.set_location(db, params)
		id = params["id"]
		db.execute("DELETE FROM WeatherLocation;")
		db.execute("INSERT INTO WeatherLocation Values(?);", [id])
		return ""
	end

	def self.tile(db)
		date = Time.now.strftime("%d/%m/%Y")

		begin
			city = db.execute("SELECT location FROM WeatherLocation;")[0][0]
			weather = OpenWeather::Current.city_id(city)
		rescue
			return {:color => "red", :front => {:title => "Error fetching weather", :content => ["Either the providor is down or the location is not set."]}, :back => {:content => []}}
		end
		return {:color => "blue",
			:front => {
				:title => "#{weather["name"]} Weather",
				:content => [
					"<b>#{weather["weather"][0]["main"]}</b>",
                                        "Today's weather is #{weather["weather"][0]["description"]}"
                                ]
			},		
			:back => {
				:title => "Example tile",
				:content => [
					"Today's date is #{date}",
					"Click to view the weather"
				]
			}
		       }
	end
end
