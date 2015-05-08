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
		begin
			id.to_i
			db.execute("DELETE FROM WeatherLocation;")
			db.execute("INSERT INTO WeatherLocation Values(?);", [id])
			return "ok"
		rescue
			return "invalid"
		end
	end

	def self.tile(db)
		begin
			date = Time.now.strftime("%B %d, %Y")
			city = db.execute("SELECT location FROM WeatherLocation;")[0][0]
			weather = OpenWeather::Current.city_id(city)
			forecast = OpenWeather::Forecast.city_id(city)
			temp = ((weather["main"]["temp"].to_i - 273.15)* 1.8 + 32).to_i
			high = ((weather["main"]["temp_max"].to_i - 273.15)* 1.8 + 32).to_i
			low = ((weather["main"]["temp_max"].to_i - 273.15)* 1.8 + 32).to_i

			max_days = 7
			display_days = []
			dates_added = []
			forecast["list"].each do |event|
				break if display_days.size == max_days
				event_time = Time.at(event["dt"])
				day = event_time.day
				next if dates_added.include? day
				if event_time.hour > 11 and event_time.hour < 16
					display_days << event
					dates_added << day
				end
			end

			days = {
				0 => "Sunday",
				1 => "Monday",
				2 => "Tuesday",
				3 => "Wednesday",
				4 => "Thursday",
				5 => "Friday",
				6 => "Saturday"
			}
			forecast_str  = "<center><table>"
			display_days.each do |day|
				day_time = Time.at(day["dt"])
				date_str = "#{day_time.month}/#{day_time.day}"
				day_temp = ((day["main"]["temp"].to_i - 273.15)* 1.8 + 32).to_i
				forecast_str += "<tr><td class=\"white-text\">#{days[day_time.wday]}</td>
						<td class=\"white-text\">#{date_str}</td>
						<td class=\"white-text\">#{day["weather"][0]["main"]}</td>
						<td class=\"white-text\"><img src=\"http://openweathermap.org/img/w/#{day["weather"][0]["icon"]}.png\"></td>
						<td class=\"white-text\">#{day_temp}&#176;F</td>"
			end
			forecast_str += "</table></center>"

			return {:color => "green",
				:front => {
					:title => "#{weather["name"]} Weather",
					:body => "<center>#{date}</center><br /><br />
						  <p>
							<font class=\"white-text\" size=\"9\">#{weather["weather"][0]["main"]}</font>
							<img src=\"http://openweathermap.org/img/w/#{weather["weather"][0]["icon"]}.png\">
						  </p>
						  <p>
							<font size=\"8\">#{temp}&#176;F</font>&nbsp;&nbsp;<font size=\"4\">High: #{high}&#176;F / Low: #{low}&#176;F</font>
						  </p>
						  <br /><br /><br /><br /><br /><br />
						  <p>
							Click to view weekly forecast</p>
						  </p>"
				},		
				:back => {
					:title => "Forecast",
					:body => forecast_str
				}
			       }
		rescue => e
			return {:color => "red", :front => {:title => "Error fetching weather", :body => "<p>Error getting weather, service is down or city has not been set.<br /><br />#{e.to_s}</p>"}}
		end
	end
end
