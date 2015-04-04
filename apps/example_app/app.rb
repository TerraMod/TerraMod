class DemoApp

	def self.requirements
		return {"Door" => {:class => "EntranceSensor",
				   :description => "Door to alert"},
			"PIR" =>  {:class => "MotionSensor",
				   :description => "PIR to alert"},
		        "Integer" => {:class => "Fixnum",
				      :description => "Example integer"}
			}
	end

	def self.setup(db, devices)
		# Create app table
		db.execute "CREATE TABLE DemoApp(name TEXT, uuid TEXT);"

		# Parse devices input and insert into app and callbacks tables
		devices.each do |k, v|
			db.execute "INSERT INTO DemoApp VALUES(?, ?);", [k, v]
			db.execute "INSERT INTO Callbacks VALUES (?, ?);", [v, "DemoApp"]
		end
		#return errors?

		# Populate apps table with app information
		name = "Example Application"
		description = "This application demonstrates the TerraMod framework.  The goal is to print any sensor to standard output."
		object = "DemoApp"
		page = "/routing/information?"
		version = "0.1"
		db.execute "INSERT INTO Apps VALUES(?, ?, ?, ?, ?);", [name, description, object, page, version]
	end

	def self.tile
		return {:title => "Example App",
			:content => "example tile content"}
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
