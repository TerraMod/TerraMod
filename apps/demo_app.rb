class DemoApp

	def self.requirements
		return {"Door" => {:class => "EntranceSensor",
				   :description => "Door to alert"},
			"PIR" =>  {:class => "MotionSensor",
				   :description => "PIR to alert"}
		       }
	end

	def self.setup(db, devices)
		db.execute "CREATE TABLE DemoApp(name TEXT, uuid TEXT);"
		devices.each do |k, v|
			db.execute "INSERT INTO DemoApp VALUES(?, ?);", [k, v]
			db.execute "INSERT INTO Callbacks VALUES (?, ?);", [v, "DemoApp"]
		end
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
