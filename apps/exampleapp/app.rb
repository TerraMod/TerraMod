require 'open_weather'

class ExampleApp

	@@name		= "Example Application"
	@@version	= "0.1"
	@@description	= "This application demonstrates the TerraMod framework.  The goal is to print any sensor to standard output."

	def self.install_tables(db)
		# Create table(s) to store app information
		#db.execute "CREATE TABLE DemoApp(name TEXT, uuid TEXT);"
	end

	def self.remove_tables(db)
		# Drop all tables created by the app
		#db.execute "DROP TABLE DemoApp;"
	end

	def self.routes
		return [{
				:verb => "get",
				:url => "dashboard",
				:template => :dashboard
			}
		]
	end

	def self.callback(db, uuid, data)
		#component = db.execute "SELECT name FROM DemoApp WHERE uuid=?;", [uuid]
		#component = component[0][0]
		#details = db.execute "SELECT name,room FROM Modules WHERE uuid=?", [uuid]
		#name = details[0][0]
		#room = details[0][1]
		#if component == "Door"
		#	puts "DemoApp: #{name} in #{room} changed to state #{data}"
		#elsif component == "PIR"
		#	puts "DemoApp: #{data} detection on #{name} in #{room}"
		#end
	end
end
