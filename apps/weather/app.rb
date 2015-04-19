require 'open_weather'

class Weather

	@@name		= "Weather"
	@@version	= "1.0"
	@@description	= "This application provides a descriptive weather tile for the dashboard."

	# setting for city ID

	def self.tile
		date = Time.now.strftime("%d/%m/%Y")
		begin
			weather = OpenWeather::Current.city_id("5750162")
		rescue
			return {:color => "red", :front => {:title => "Error fetching weather", :content => ["Please refresh"]}, :back => {:content => []}}
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
