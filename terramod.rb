#!/usr/bin/env ruby

require 'sinatra/base'
require 'json'
require 'sqlite3'
require 'net/http'
require 'zip'
require 'fileutils'
require 'pathname'

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
                        get url do	# get "app.dur"+url
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
			db.execute "CREATE TABLE Callbacks(uuid TEXT, event TEXT, class TEXT, method TEXT);"
			db.execute "CREATE TABLE Apps(name TEXT, version TEXT, object TEXT, description TEXT, page TEXT, dir TEXT, UNIQUE(object), UNIQUE(page), UNIQUE(dir));"
		end

		set :install, self.method(:install)
		set :db, db
		set :port, 80
		set :bind, "0.0.0.0"
		
	end
	
	helpers do

		def render_admin(message=nil)
	                modules = []
	                settings.db.execute("SELECT type,name,room,uuid,nexus_uuid FROM Modules;").each do |row|
        	                mod = {:type => row[0],
                	               :name => row[1],
                        	       :room => row[2],
				       :uuid => row[3]
	                        }
        	                nexus_uuid = row[4]
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
	                                        :modules => modules,
        	                                :message => message}
		end

		def render_manage_apps(message=nil)
			erb :manage_apps, :locals => {:app_links => settings.db.execute("SELECT name,page FROM Apps;"),
                        			      :apps => settings.db.execute("SELECT name,version,object,description FROM Apps;"),
						      :message => message}
		end

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
				settings.db.execute "INSERT OR REPLACE INTO Modules VALUES(?,?,?,?,?);", [module_uuid, uuid, name, room, type]
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

		begin
			# Note the entries in 'apps' to preserve if the app upload fails
			entries = Dir["./apps/*"]

			# Upload app zip
			zip_filename = File.basename(params[:appfile][:filename])
			zip_filename = "./apps/" + zip_filename
			file = params[:appfile][:tempfile]
			File.open(zip_filename, 'wb') { |zip_file| zip_file.write(file.read) }

			# Extract and check zip
			app_dir = ""
			extracted = []
			Zip::File.open(zip_filename) do |open_zip|
				open_zip.each do |zipped_file|
					path = Pathname.new(zipped_file.name).each_filename.to_a
					if File.basename(zipped_file.name) == "app.rb" and path.size == 2
						app_dir = path[0]
					end
					destination = "./apps/" + zipped_file.name
					zipped_file.extract destination
					extracted << destination
				end
			end
			raise "no app.rb in first directory of zip" if app_dir == ""
			File.delete(zip_filename)

			# Load app zip, lookup class name and try to install
			require "./apps/#{app_dir}/app.rb"
			class_name = (/class \w+/.match File.read("./apps/#{app_dir}/app.rb")).to_s.split(" ")[1]
			app = Module.const_get(class_name)
			settings.install.(app)
			name = app.class_variable_get(:@@name)
			version = app.class_variable_get(:@@version)
			description = app.class_variable_get(:@@description)
			dashboard = app.class_variable_get(:@@dashboard)
			settings.db.execute "INSERT INTO Apps VALUES(?, ?, ?, ?, ?, ?);", [name, version, class_name, description, dashboard.to_s, app_dir]

			redirect to("/app_detail/#{class_name}")

		rescue => e
			(Dir["./apps/*"] - entries).each { |item| FileUtils.rm_rf item }
			render_manage_apps({
                                :class => "alert-danger",
                                :title => "Error:",
                                :detail => e.to_s
                        })
		
		end

	end

	get '/uninstall_app/:app' do |app_obj|

		count = settings.db.execute("SELECT COUNT(*) FROM Apps WHERE object=?;", [app_obj])[0][0].to_i
                ( status 404; return ) if count == 0
                app = Module.const_get(app_obj)

		begin
			FileUtils.rm_rf("./apps/" + settings.db.execute("SELECT dir FROM Apps WHERE object=?", [app_obj])[0][0])
			app.uninstall(settings.db)
			settings.db.execute "DELETE FROM Apps WHERE object=?;", [app_obj]
			settings.db.execute "DELETE FROM Callbacks WHERE class=?;", [app_obj]
			message = {
				:class => "alert-success",
                        	:title => "Success:",
                	        :detail => "uninstalled #{app.class_variable_get(:@@name)}"
			}
		rescue => e
			message = {
                                :class => "alert-danger",
                                :title => "Error:",
                                :detail => e.to_s
                        }
		end

		render_manage_apps(message)

	end


	get '/app_detail/:app' do |app_obj|

		count = settings.db.execute("SELECT COUNT(*) FROM Apps WHERE object=?;", [app_obj])[0][0].to_i
		( status 404; return ) if count == 0
		app = Module.const_get(app_obj)

		erb :app_detail, :locals => {:app_links => settings.db.execute("SELECT name,page FROM Apps;"),
					     :app => settings.db.execute("SELECT name,version,page,description,object FROM Apps WHERE object=?;", [app_obj])[0],
					     :modules => settings.db.execute("SELECT * FROM Modules;")}	# maybe send the db to the application here?

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
		render_manage_apps
	end
	
	get '/admin' do
		render_admin
	end

	get '/clear_modules' do

		settings.db.execute "DROP TABLE Modules;"
		settings.db.execute "CREATE TABLE Modules(uuid TEXT, nexus_uuid TEXT, name TEXT, room TEXT, type TEXT, UNIQUE(uuid));"

		render_admin({
			:class => "alert-success",
			:title => "Cleared:",
			:detail => "the Modules table has been cleared"
		})

	end

	get '/nexus_scan' do

		requests = []
		settings.db.execute("SELECT ip FROM Nexus;").each do |ip|
			requests << Thread.new{
						begin
							Net::HTTP.get(URI.parse("http://#{ip[0]}/report_modules"))
						rescue
						end
						}
		end
	
		requests.each { |req| req.join }
		sleep(4)
	
		render_admin({
                        :class => "alert-success",
                        :title => "Scanned:",
                        :detail => "all Nexus devices asked to report modules"
                })

	end

	get '/query_module/:module_uuid' do |module_uuid|	# should be moved into the apps
		begin
			nexus_uuid = settings.db.execute("SELECT nexus_uuid FROM Modules WHERE uuid=?;", [module_uuid])[0]
		rescue
			status 404
			return
		end
		if !nexus_uuid
			return "disconnected nexus"
		end
		nexus_ip = settings.db.execute("SELECT ip FROM Nexus WHERE uuid=?;", nexus_uuid)[0][0]
		resp = Net::HTTP.get(URI.parse("http://#{nexus_ip}/query/#{module_uuid}"))
		return resp
	end

	get '/rename/:module_uuid/:new_name/:new_room' do |module_uuid, new_name, new_room|
                begin
                        nexus_uuid = settings.db.execute("SELECT nexus_uuid FROM Modules WHERE uuid=?;", [module_uuid])[0]
                rescue
                        status 404
                        return
                end
                if !nexus_uuid
                        return "disconnected nexus"
                end
                nexus_ip = settings.db.execute("SELECT ip FROM Nexus WHERE uuid=?;", nexus_uuid)[0][0]
                resp = Net::HTTP.get(URI.parse(URI.encode("http://#{nexus_ip}/rename/#{module_uuid}/#{new_name}/#{new_room}")))
                return resp
        end

	
end

TerraMod.run!
