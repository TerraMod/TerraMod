#Keywords: many to many, foreign key
#require 'sqlite3'
require 'lifx'
class Greenlights

	@@name		= "Greenlights"
	@@version	= "0.1"
	@@description	= "This application demonstrates the Greenlights on the TerraMod framework."

	###############################################################
	#rules
		#Describes how rules are triggered
			#time - a tuple with :start and :end
			#list of profiles they belong to - a foreign key pointing to a row of profiles
			#callbacks - foreign key pointing to a row of callbacks
		#Describes what to do once selected
			#color - color properties for lifx
			#light group - 
			#credits
	#profile
		#rules
	#light group
		#list of lights
	#light
		#list of light groups it belongs to
	#bool method is_it_time?
	#callback -> get rules[] -> resolve rules[]
	################################################################
	def self.install_tables(db)
		puts "install tables"
		#not sure if I need a name field yet
		#TODO: build a light exclusion table
		remove_tables(db)
		
		db.execute "CREATE TABLE Lights(id INTEGER PRIMARY KEY, 
										label TEXT, 
										credits INTEGER
										);"
		
		
		db.execute "CREATE TABLE Profiles(id INTEGER PRIMARY KEY,
			 							  name TEXT
										  );"
								  
		db.execute "CREATE TABLE Rules(id INTEGER PRIMARY KEY,
									   name TEXT,
									   start_time INTEGER,
									   end_time INTEGER,
									   color TEXT,
									   credits INTEGER
									   );"
									   
		db.execute "CREATE TABLE rule_light_junction(rule_id integer,
													 light_id integer,
													 FOREIGN KEY(rule_id) REFERENCES Rules(id) ON DELETE CASCADE,
													 FOREIGN KEY(light_id) REFERENCES Lights(id) ON DELETE CASCADE
													 );"
									   
		db.execute "CREATE TABLE rule_profile_junction(rule_id INTEGER, 
													   profile_id INTEGER, 
													   FOREIGN KEY(rule_id) REFERENCES Rules(id) ON DELETE CASCADE, 
													   FOREIGN KEY(profile_id) REFERENCES Profiles(id) ON DELETE CASCADE
													   );"
									   
		db.execute "CREATE TABLE rule_callback_junction(rule_id INTEGER,
														callback_uuid TEXT,
														FOREIGN KEY(rule_id) REFERENCES Rules(id) ON DELETE CASCADE
														);"
		
		db.execute "CREATE TABLE Active_profile(profile INTEGER,
												FOREIGN KEY(profile) REFERENCES Profiles(id)
												);"
												
		#Active profile business assumes the profile in the first position is always the active one, so alter it accordingly
		db.execute("INSERT INTO Active_profile(profile) VALUES(null);")
		modules = db.execute("SELECT uuid FROM Modules;")
		modules.flatten
		add_callbacks(db, modules)
		
		puts "test init called"
		test_init(db)
	end

	def self.remove_tables(db)
		# Drop all tables created by the app
		db.execute "DROP TABLE IF EXISTS Lights;"
		db.execute "DROP TABLE IF EXISTS Profiles;"
		db.execute "DROP TABLE IF EXISTS Rules;"
		db.execute "DROP TABLE IF EXISTS Active_profile;"
		db.execute "DROP TABLE IF EXISTS rule_profile_junction;"
		db.execute "DROP TABLE IF EXISTS rule_callback_junction;"
		db.execute "DROP TABLE IF EXISTS rule_light_junction;"
	end
	
	# Interface with hardware
	def self.callback(db, uuid, data)
		puts "callback"
		# Foreign key of the active profile, in Profiles
		active_profile = db.execute "SELECT profile FROM Active_profile;"
		puts "active profile = #{active_profile.flatten}"
		# Get the rules in the active profile
		rules = db.execute("SELECT rule_profile_junction.rule_id FROM rule_profile_junction WHERE profile_id=? INTERSECT 
									SELECT rule_callback_junction.rule_id FROM rule_callback_junction WHERE callback_uuid=?", [active_profile, uuid])
		puts "rules = #{rules.flatten}"
		puts rules
		rules.each do |rule_id|
			if(is_time?(db, rule_id))
				resolve(db, rule_id)
			end
		end
	end
	
	#assume profiles to be a list of foreign keys
	def self.add_rule(name, start, ending, profiles, callbacks, color, credits, lights)
		#insert the rule data
		#we need seperate db access here in order to retain the rule_id
		puts "add rule"
		begin
			db_file = "/home/pi/TerraMod/terramod.db"
			database = SQLite3::Database.open(db_file)
			puts "database opened"
			database.execute("INSERT INTO Rules(name, start_time, end_time, color, credits) VALUES(?, ?, ?, ?, ?);", 
				[name, start, ending, color, credits])
			rule_id = database.execute "select last_insert_rowid();"
			puts rule_id
			#hook the rule data up to the proper junctions
			profiles.each do |profile|
				database.execute("INSERT INTO rule_profile_junction VALUES(?,?);", [rule_id[0][0], profile])
			end
			#hook up callbacks
			callbacks.each do |callback|
				database.execute("INSERT INTO rule_callback_junction VALUES(?,?);", [rule_id[0][0], callback])
			end
			#hook up lights
			lights.each do |light|
				database.execute("INSERT INTO rule_light_junction VALUES(?,?);", [rule_id[0][0], light])
			end
			database.close
		rescue SQLite3::Exception => e
			puts e
			database.close if database
		end
	end
	
	#TODO: test this shit!
	def self.remove_rule(db, id)
		#this SHOULD cascade and remove the junctions too... keyword should
		db.execute("DELETE FROM Rules WHERE id=?;", [id])
	end
	
	def self.resolve(db, rule_id)
		data = db.execute("SELECT color, credits FROM Rules WHERE id=?;", rule_id)
		color_data = data[0][0]
		credits = data[0][1]
		light_ids = db.execute("SELECT light_id FROM rule_light_junction WHERE rule_id=?;", rule_id)
		light_ids.flatten
		puts light_ids.inspect
		lifx = LIFX::Client.lan
		lifx.discover!
		
		case color_data
		when "red"
			color = LIFX::Color.red(saturation: 0.4)
		when "blue"
			color = LIFX::Color.blue(saturation: 0.4)
		when "yellow"
			color = LIFX::Color.yellow(saturation: 0.4)
		when "green"
			color = LIFX::Color.green(saturation: 0.4)
		else
			color = LIFX::Color.purple(saturation: 0.4)
		end
		
		light_ids.each do |id|
			light_info = db.execute("SELECT label, credits FROM Lights WHERE id=?;", id)
			puts light_info.inspect
			
			light_label = light_info[0][0]
			puts light_label
			light_credits = light_info[0][1]
			
			lights = lifx.lights.with_label(light_label)
			puts lights
			
			if(credits > light_credits || credits == -1)
				begin
					lights.set_color(color, duration: 5)
					lights.turn_on!
				rescue
					lights.set_color(color, duration: 5)
				ensure
					db.execute("UPDATE Lights SET credits=? WHERE id=?;", [credits, light_ids])
				end
			elsif(credits == 0)
				db.execute("UPDATE Lights SET credits=? WHERE id=?;", [credits, light_ids])
				begin
					lights.turn_off!
				rescue
				end
			end
		end
		
	end
	
	# Given the start and stop times for a rule, determine if it's time to do it
	def self.is_time?(db, rule_id)
		times = db.execute("SELECT start_time, end_time FROM Rules WHERE id=?", rule_id)
		start = times[0][0]
		finish = times[0][1]
		#times = [[0, 1]]
		puts "start time is #{times[0][0]}"
		puts "end time is #{times[0][1]}"
=begin
		start_hour = start.hour*60*60
		start_min = start.min*60
		start_sec = start.sec
		start_final = start_hour + start_min + start_sec
		
		finish_hour = finish.hour*60*60
		finish_min = finish.min*60
		finish_sec = finish.sec
		finish_final = finish_hour + finish_min + finish_sec
=end
		now = Time.now
		now_hour = now.hour*60*60
		now_min = now.min*60
		now_sec = now.sec
		now = now_hour + now_min + now_sec
		
		if(start > finish)
			start = start - (24*60*60)
		end
		
		return (now >= start && now <= finish)

	end
	
	def self.add_profile(db, name)
		db.execute("INSERT INTO Profiles(name) VALUES(?);", name)
	end
	
	def self.remove_profile(db, id)
		db.execute("DELETE FROM Profiles WHERE id=?;", id)
	end
	
	def self.copy_profile
	
	end
	
	def self.copy_rule
	
	end
	
	def self.add_light(db, label)
		db.execute("INSERT INTO Lights(label, credits) VALUES(?,?);", [label, 0])
	end
	
	def self.remove_light(db, id)
		db.execute("DELETE FROM Lights WHERE id=?;", id)
	end
	
	def self.set_active_profile(db, id)
		db.execute("UPDATE Active_profile SET profile=?;", id)
	end
	
	def self.add_callbacks(db, modules)
		modules.each do |uuid|
			db.execute("INSERT INTO Callbacks Values(?,?,?,?);", [uuid, "\\w+", "Greenlights", "callback"])
		end
	end
	
	def self.test_init(db)
		name = "test"
		#create a test profile
		add_profile(db, name)
		#query for it
		active_id = db.execute("SELECT id FROM Profiles WHERE name=?;", name)
		#make it the active profile
		set_active_profile(db, active_id)
		add_light(db, "Room")
		add_rule("test rule", 0, 86399, active_id, ["934d38cc-8fd2-4ac3-9b4d-059712a7a08b"], "red", 1, [1])
	end
end
