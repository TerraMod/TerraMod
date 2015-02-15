#!/usr/bin/env ruby

require 'sinatra/base'


class EventReciever < Sinatra::Base
	# recieve requests from the nexus and send them to callbacks for the apps
	
	configure do
		# set globally avaliable event queues for callbacks?
	end
	
	post '/add_modules' do
		# Called when a nexus comes online
		# insert into database the presence of this nexus
	end
end

class Controller < Sinatra::Base
	# Present the web interface and API

	configure do
		#db_flie = "/home/hayden/Downloads/controller.db"
		#File.delete(db_flie) if File.exist?(db_flie)
		#db = SQLite3::Database.new db_flie
		#db.execute "CREATE TABLE Nexus(uuid TEXT, name TEXT, class TEXT, room TEXT, hardware TEXT, UNIQUE(uuid));"
		
	end

	get '/' do
		erb '<h1>TerraMod Dashboard</h1>'
	end
	
end


Controller.run!
