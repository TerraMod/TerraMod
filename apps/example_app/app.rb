require 'open_weather'

class ExampleApp

	@@name = "Example Application"
	@@version = "0.1"
	@@description = "This application demonstrates the TerraMod framework.  The goal is to print any sensor to standard output."
	@@dashboard = true

	def self.install(db)
		# Create table(s) to store app information
		db.execute "CREATE TABLE DemoApp(name TEXT, uuid TEXT);"
	end

	def self.uninstall(db)
		# Drop all tables created by the app
		db.execute "DROP TABLE DemoApp;"
	end

	def self.tile
		date = Time.now.strftime("%d/%m/%Y")
		begin
			weather = OpenWeather::Current.city_id("5750162")
		rescue
			weather = "Weather download failed, please refresh"
		end
		return {:color => "green",
			:front => {
				:title => "Example tile",
				:content => [
					"Today's date is #{date}",
					"Click to view the weather"
				]
			},
			:back => {
				:title => "#{weather["name"]} Weather",
				:content => [
					"<b>#{weather["weather"][0]["main"]}</b>",
                                        "Today's weather is #{weather["weather"][0]["description"]}"
                                ]
			}		
		       }
	end

	def self.routes
		return [{
			:url => "/example_app",
			:template => :template,
			:views => "./apps/example_app/",
			:locals => {
				:modules => ["SELECT uuid,name,room FROM Modules;", []]
				}
		}	# set template free pages?  force ruby into the erb files?
		]
	end

	def self.callback(db, uuid, data)
		component = db.execute "SELECT name FROM DemoApp WHERE uuid=?;", [uuid]
		component = component[0][0]
		details = db.execute "SELECT name,room FROM Modules WHERE uuid=?", [uuid]
		name = details[0][0]
		room = details[0][1]
		if component == "Door"
			puts "DemoApp: #{name} in #{room} changed to state #{data}"
		elsif component == "PIR"
			puts "DemoApp: #{data} detection on #{name} in #{room}"
		end
	end
end
