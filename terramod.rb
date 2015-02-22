#!/usr/bin/env ruby

require 'sinatra/base'

class EventReciever < Sinatra::Base
	# recieve requests from the nexus and send them to callbacks for the apps
	
	configure do
		# access database
	end
	
	post '/event_reciever' do
		event = JSON.parse request.body.read
		type = event['type']
		uuid = event['uuid']
		data = event['data']
		if type == "ModuleReport"
			#settings.db.execute "DROP TABLE ?;" [uuid]
			#modules = JSON.parse data
			#settings.db.execute "CREATE TABLE ?(uuid TEXT, name TEXT, class TEXT, room TEXT, UNIQUE(uuid));" [uuid]
			##settings.db.execute "INSERT INTO nexus VALUES(?,?);" [uuid, request.ip]
			#modules.each do |k, v|
				#module_uuid = k
				#name = v['name']
				#type = v['type']
				#room = v['room']
				#settings.db.execute "INSERT INTO ? VALUES(?,?,?,?);", [uuid, name, type, room]
			#end
		elsif type == "EventReport"
			#callbacks = settings.db.execute "SELECT method FROM callbacks WHERE module_uuid = ?;" [uuid]
			#callbacks.each do |callback|
				#method = Module.const_get(callback[0])
				#method(data)
			#end
		end
	end
	
end

class Controller < Sinatra::Base

	configure do
		#db_flie = "/./terramod.db"
		#db = SQLite3::Database.new db_flie
		#db.execute "CREATE TABLE nexus(uuid TEXT, ip TEXT, UNIQUE(uuid));"
		
	end

	get '/' do
		erb '<h1>TerraMod Dashboard</h1>'
	end
	
end


