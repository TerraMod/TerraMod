require 'open_weather'

class ExampleApp

	@@name		= "Example Application"
	@@version	= "0.1"
	@@description	= "This application demonstrates the TerraMod framework.  The goal is to print any sensor to standard output."

	def self.install_tables(db)
		db.execute("INSERT INTO Callbacks VALUES(?, ?, ?, ?);", ["934d38cc-8fd2-4ac3-9b4d-059712a7a08b", "\\w+", "ExampleApp", "callback"])
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
		puts "exampleapp callback called on #{uuid} callback=#{data}"
	end
end
