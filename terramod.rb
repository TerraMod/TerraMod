#!/usr/bin/env ruby

require 'sinatra/base'
require 'json'
require 'sqlite3'

class TerraMod < Sinatra::Base
	
	configure do
		
		db_file = "./terramod.db"
		File.delete db_file if File.exists? db_file
		db = SQLite3::Database.new db_file
		db.execute "CREATE TABLE Nexus(uuid TEXT, ip TEXT, UNIQUE(uuid));"
		db.execute "CREATE TABLE Modules(uuid TEXT, nexus_uuid TEXT, name TEXT, room TEXT, type TEXT, UNIQUE(uuid));"
		db.execute "CREATE TABLE Callbacks(uuid TEXT, method TEXT);"
		
		set :db, db
		set :port, 80
		set :bind, "0.0.0.0"
		
	end
	
	post '/event_reciever' do
		event = JSON.parse request.body.read
		type = event['type']
		uuid = event['uuid']
		data = event['data']
		if type == "ModuleReport"
			settings.db.execute "INSERT OR IGNORE INTO Nexus VALUES(?,?);", [uuid, request.ip]
			settings.db.execute "UPDATE Nexus SET ip=? WHERE uuid=?;", [request.ip, uuid]
			data.each do |k, v|
				module_uuid = k
				name = v['name']
				type = v['type']
				room = v['room']
				settings.db.execute "INSERT OR IGNORE INTO Modules VALUES(?,?,?,?,?);", [module_uuid, uuid, name, room, type]
			end
		elsif type == "EventReport"
			callbacks = settings.db.execute "SELECT method FROM Callbacks WHERE uuid=?;", [uuid]
			callbacks.each do |callback|
				method = Module.const_get(callback[0])
				method(uuid, data)
			end
		end
		status 200
	end
	
	get '/' do
		erb '<h1>TerraMod Dashboard</h1>'
	end	
	
end

TerraMod.run!
