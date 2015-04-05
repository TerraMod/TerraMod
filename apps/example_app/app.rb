require 'open_weather'

class ExampleApp

	@@name = "Example Application"
	@@version = "0.1"
	@@object = "ExampleApp"
	@@description = "This application demonstrates the TerraMod framework.  The goal is to print any sensor to standard output."
	@@page = "/example_app"
	@@dir = "example_app"

	def self.requirements
		return {"Door" => {:class => "EntranceSensor",
				   :description => "Door to alert"},
			"PIR" =>  {:class => "MotionSensor",
				   :description => "PIR to alert"},
		        "Integer" => {:class => "Fixnum",
				      :description => "Example integer"}
			}
	end

	def self.set_options(db, options)
		# update all table with relevent information


		# clear out and fill the 'ExampleApp" tables
		#devices.each do |k, v|
                #        db.execute "INSERT INTO DemoApp VALUES(?, ?);", [k, v]
                #        db.execute "INSERT INTO Callbacks VALUES (?, ?);", [v, "DemoApp"]
                #end

	end

	def self.install(db)
		# Create table(s) to store app information
		db.execute "CREATE TABLE DemoApp(name TEXT, uuid TEXT);"

		# Populate Apps table with app information
		db.execute "INSERT INTO Apps VALUES(?, ?, ?, ?, ?, ?);", [@@name, @@version, @@object, @@description, @@page, @@dir]
	end

	def self.uninstall(db)
		# Drop all tables created by the app, remove from Apps table
		db.execute "DROP TABLE DemoApp;"
		db.execute "DELETE FROM Apps WHERE object=?;", [@@object]
	end

	def self.tile
		date = Time.now.strftime("%d/%m/%Y")
		weather = OpenWeather::Current.city_id("5750162")
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
		}
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
