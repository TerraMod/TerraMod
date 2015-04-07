#!/usr/bin/env ruby

require 'sinatra/base'
require 'json'
require 'sqlite3'
require 'net/http'
require 'zip'
require 'fileutils'

Dir["./apps/*/app.rb"].each {|file| require file }

class TerraMod < Sinatra::Base

	def self.register_routes(app)
		app.routes.each do |hookup|
                        url = hookup[:url]
                        template = hookup[:template]
                        views = hookup[:views]
			locals = hookup[:locals]
			query = Proc.new {
				results = {}
				locals.each do |k, v|
					results[k] = settings.db.execute v[0], v[1]
				end
				results
			}
                        get url do
                                erb template, :views => views,
                                              :layout_options => { :views => 'views' },
                                              :locals => {:app_links => settings.db.execute("SELECT name,page FROM Apps;"),
							  :queries => query.call}
                        end
		end
	end

	def self.install(app)
		app.install(settings.db)
                register_routes(app)
	end
	
	configure do
		
		db_file = "./terramod.db"
		db = nil
		if File.exists? db_file
			db = SQLite3::Database.open db_file
			db.execute("SELECT object FROM Apps;").each do |app|
				register_routes(Module.const_get(app[0]))
			end
		else
			db = SQLite3::Database.new db_file
			db.execute "CREATE TABLE Nexus(uuid TEXT, ip TEXT, UNIQUE(uuid));"
			db.execute "CREATE TABLE Modules(uuid TEXT, nexus_uuid TEXT, name TEXT, room TEXT, type TEXT, UNIQUE(uuid));"
			db.execute "CREATE TABLE Callbacks(uuid TEXT, class TEXT, method TEXT);"
			db.execute "CREATE TABLE Apps(name TEXT, version TEXT, object TEXT, description TEXT, page TEXT, dir TEXT, UNIQUE(object), UNIQUE(page), UNIQUE(dir));"
		end

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

	post '/install_app' do
		# (/class \w+/.match File.read("app.rb")).to_s.split(" ")[1] # "class in file"
		begin
			filename = params[:appfile][:filename]
			app_zip = "./apps/" + filename
			file = params[:appfile][:tempfile]
			File.open(app_zip, 'wb') do |f|
				f.write(file.read)
			end
			Zip::File.open(app_zip) do |open_zip|
				open_zip.each do |zipped_file|
					zipped_file.extract "./apps/" + zipped_file.name
				end
			end
			File.delete(app_zip)
			dir_name = filename.split(".")[0]
			class_name = dir_name.split('_').collect(&:capitalize).join
			require "./apps/#{dir_name}/app.rb"
			settings.install.(Module.const_get(class_name))
			err_message = ""
		rescue => e
			begin
				File.delete(app_zip)
			rescue
			end
			err_message = e.to_s
		end

		message = {}
		if err_message == ""
			message = {
				:class => "alert-success",
                                :title => "Success:",
                                :detail => "Your app has been installed to /apps/#{dir_name}/.  Please select it from the list below to configure."
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
		begin
                        app = Module.const_get(params['app'])
			FileUtils.rm_rf("./apps/" + app.class_variable_get(:@@dir))
			app.uninstall(settings.db)
			err_message = ""
                rescue => e
                        err_message = e.to_s
                end

		message = {}
		if err_message == ""
			message = {
				:class => "alert-success",
                        	:title => "Success:",
                	        :detail => "uninstalled #{app.class_variable_get(:@@name)}"
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

	get '/' do
		tiles = []
		apps = settings.db.execute("SELECT object FROM Apps;")
		apps.each do |row|
			object = Module.const_get(row[0])
			if object.methods.include? :tile
				tile = object.tile
				tile[:object] = row[0]
				tiles << tile
			end
		end
		erb :dashboard, :locals => {:app_links => settings.db.execute("SELECT name,page FROM Apps;"),
					:tiles => tiles}
	end
	
	get '/manage_apps' do
		erb :manage_apps, :locals => {:app_links => settings.db.execute("SELECT name,page FROM Apps;"),
					      :apps => settings.db.execute("SELECT name,version,object,description FROM Apps;")}
	end
	
	get '/admin' do

		modules = []
		settings.db.execute("SELECT type,name,room,nexus_uuid FROM Modules;").each do |row|
			mod = {:type => row[0],
			       :name => row[1],
			       :room => row[2]
			}
			nexus_uuid = row[3]
			mod[:nexus_ip] = settings.db.execute("SELECT ip FROM Nexus WHERE uuid=?;", [nexus_uuid])[0][0]
			modules << mod
		end

		callbacks = []
		settings.db.execute("SELECT * FROM Callbacks;").each do |row|
			mod = settings.db.execute("SELECT name,room FROM Modules WHERE uuid=?;", [row[0]])[0]
			call = {:module => "#{mod[0]} in #{mod[0]}",
				:class => row[1],
				:method => row[2]
			}
			callbacks << call
		end

		erb :admin, :locals => {:app_links => settings.db.execute("SELECT name,page FROM Apps;"),
					:app_count => settings.db.execute("SELECT count(object) FROM Apps;")[0][0],
					:module_count => settings.db.execute("SELECT count(uuid) FROM Modules;")[0][0],
					:nexus_count => settings.db.execute("SELECT count(uuid) FROM Nexus;")[0][0],
					:callbacks => callbacks,
					:modules => modules}
	end

	get '/query_module/:uuid' do
		module_uuid = params['uuid']
		nexus_uuid = settings.db.execute("SELECT nexus_uuid FROM Modules WHERE uuid=?;", [module_uuid])[0]
		if !nexus_uuid
			return "disconnected nexus"
		end
		nexus_ip = settings.db.execute("SELECT ip FROM Nexus WHERE uuid=?;", nexus_uuid)[0][0]
		resp = Net::HTTP.get(URI.parse("http://#{nexus_ip}/query/#{module_uuid}"))
		return resp
	end
	
end

TerraMod.run!
