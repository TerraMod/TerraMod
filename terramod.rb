#!/usr/bin/env ruby

require 'sinatra/base'
require 'json'
require 'sqlite3'

Dir["./apps/*.rb"].each {|file| require file }

class TerraMod < Sinatra::Base
	
	configure do
		
		db_file = "./terramod.db"
		File.delete db_file if File.exists? db_file
		db = SQLite3::Database.new db_file
		db.execute "CREATE TABLE Nexus(uuid TEXT, ip TEXT, UNIQUE(uuid));"
		db.execute "CREATE TABLE Modules(uuid TEXT, nexus_uuid TEXT, name TEXT, room TEXT, type TEXT, UNIQUE(uuid));"
		db.execute "CREATE TABLE Callbacks(uuid TEXT, class TEXT);"
		
		devices = {"Door" => "934d38cc-8fd2-4ac3-9b4d-059712a7a08b",
			   "PIR"  => "eb036152-2bb0-4b4e-afc0-5b2de33584ba"}
		DemoApp.setup(db, devices)

		set :db, db
		set :port, 8080
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
			callbacks = settings.db.execute "SELECT class FROM Callbacks WHERE uuid=?;", [uuid]
			callbacks.each do |callback|
				app_class = Module.const_get(callback[0])
				app_class.callback(settings.db, uuid, data)
			end
		end
		status 200
	end
	
	get '/' do
		erb :layout
	end
	
	get '/manage' do
		erb :layout, :layout => :manageApps
	end
	
end

TerraMod.run!
