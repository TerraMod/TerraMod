#!/usr/bin/env ruby

require 'sinatra/base'
require 'json'
require 'sqlite3'

Dir["./apps/*/app.rb"].each {|file| require file }


class TerraMod < Sinatra::Base

	def self.install(app, db)
		app.install(db)
		app.routes.each do |hookup|
                        url = hookup[:url]
                        template = hookup[:template]
                        views = hookup[:views]
                        get url do
                                erb template, :views => views,
                                              :layout_options => { :views => 'views' },
                                              :locals => {:app_links => settings.db.execute("SELECT name,page FROM Apps;")}
                        end
                end
	end
	
	configure do
		
		db_file = "./terramod.db"
		File.delete db_file if File.exists? db_file
		db = SQLite3::Database.new db_file
		db.execute "CREATE TABLE Nexus(uuid TEXT, ip TEXT, UNIQUE(uuid));"
		db.execute "CREATE TABLE Modules(uuid TEXT, nexus_uuid TEXT, name TEXT, room TEXT, type TEXT, UNIQUE(uuid));"
		db.execute "CREATE TABLE Callbacks(uuid TEXT, class TEXT);"
		db.execute "CREATE TABLE Apps(name TEXT, version TEXT, object TEXT, description TEXT, page TEXT, dir TEXT, UNIQUE(object), UNIQUE(page), UNIQUE(dir));"
	
		set :install, self.method(:install)
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
			callbacks = settings.db.execute "SELECT class FROM Callbacks WHERE uuid=?;", [uuid]
			callbacks.each do |callback|
				app_class = Module.const_get(callback[0])
				app_class.callback(settings.db, uuid, data)
			end
		end
		status 200
	end

	get '/activate' do
		settings.install.(ExampleApp, settings.db)
		"activated!"
	end

	post '/install_app' do
		
	#	app_zip = "./apps/"+params[:file][:filename]
	#	file = params[:file][:tempfile]
	#	File.open(app_zip, 'wb') do |f|
	#		f.write(file.read)
	#	end
		# unzip 

		# upload zip and unzip it in apps folder
		# require app file
		# get the class name somehow (filename in zip?)
		#settings.install.(ClassName, settings.db)

		err_message = "App installation not yet implemented."
		message = {}
		if err_message == ""
			message = {
				:class => "alert-success",
                                :title => "Success:",
                                :detail => "Your app has been installed.  Please select it from the list below to configure."
			}
		else
			message = {
				:class => "alert-danger",
				:title => "Error:",
				:detail => err_message
			}
		end
		erb :manage_apps, :locals => {:app_links => settings.db.execute("SELECT name,page FROM Apps;"),
					      :apps => settings.db.execute("SELECT name,version,object,description FROM Apps;"),
					      :message => message}
	end

	get '/edit_app/:app' do
		begin
			app = Module.const_get(params['app'])
		rescue
			status 404
			return
		end
		erb :edit_app, :locals => {:app_links => settings.db.execute("SELECT name,page FROM Apps;"),
					   :app => settings.db.execute("SELECT name,version,page,description FROM Apps WHERE object=?;", [params['app']])[0],
					   :requirements => app.requirements,
					   :modules => settings.db.execute("SELECT * FROM Modules;")}	# maybe send the db to the application here?
	end

	post '/edit_app' do
		"Saving new app options..."
	end

	get '/uninstall_app/:app' do
		message = {
			:class => "alert-warning",
                        :title => "Warning:",
                        :detail => "Deleted from the database, but not from disk"
                        }

		begin
                        app = Module.const_get(params['app'])
                rescue
                        status 404
                        return
                end
		app.uninstall(settings.db)
		# delete app from disk
		erb :manage_apps, :locals => {:app_links => settings.db.execute("SELECT name,page FROM Apps;"),
					      :apps => settings.db.execute("SELECT name,version,object,description FROM Apps;"),
					      :message => message}
	end

	get '/' do
		erb :index, :locals => {:app_links => settings.db.execute("SELECT name,page FROM Apps;")}
	end
	
	get '/manage' do
		erb :manage_apps, :locals => {:app_links => settings.db.execute("SELECT name,page FROM Apps;"),
					      :apps => settings.db.execute("SELECT name,version,object,description FROM Apps;")}
	end
	
	get '/settings' do
		erb :settings, :locals => {:app_links => settings.db.execute("SELECT name,page FROM Apps;")}
	end
	
end

TerraMod.run!
