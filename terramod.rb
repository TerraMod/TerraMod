#!/usr/bin/env ruby

require 'sinatra/base'
require 'json'
require 'sqlite3'
require 'sequel'
require 'net/http'
require 'zip'
require 'fileutils'
require 'pathname'
require 'tilt/erb'

Dir["./apps/*/app.rb"].each {|file| require file }
#Dir["./routes/*.rb"].each {|file| require file }

class TerraMod < Sinatra::Base
		#redirect_unauthenticated_to_signin
		#

	def self.register_routes(app, app_dir)
		app_class = app.ancestors[0]
		if File.exists? "./apps/#{app_dir}/views/dashboard.erb"
			get "/#{app_class}/dashboard" do
				erb :dashboard, :views => "./apps/#{app_dir}/views",
								:layout_options => { :views => 'views' }
			end
		end
		if app.methods.include? :routes
			app.routes.each do |hookup|
				verb = self.method(hookup[:verb])
				url = hookup[:url]
				template = hookup[:template]
				method = app.method(hookup[:method])
				if template != nil
					verb.("/#{app_class}/#{url}", &Proc.new {
						erb template, :views => "./apps/#{app_dir}/views",
									  :layout_options => { :views => 'views' },
									  :locals => {:params => params}
					})
				elsif method != nil
					verb.("/#{app_class}/#{url}", &Proc.new {
						return method.(settings.orm, params)
					})
				end
			end
		end
	end

	def self.install(app, dir)
		app.install_tables(settings.orm) if app.methods.include? :install_tables
		register_routes(app, dir)
	end
	
	configure do
		
		# Connect to the SQLite database
		set :orm, Sequel.connect('sqlite://terramod.db')
		
		# Create the apps table if missing
		if !settings.orm.table_exists? :apps
			settings.orm.create_table :apps do
				String :name
				String :version
				String :description
				String :object, :unique => true
				String :dir, :unique => true
			end
		end
		
		# Create the nexus table if missing
		if !settings.orm.table_exists? :nexus
			settings.orm.create_table :nexus do
				String  :uuid, :unique => true
				String  :ip
				Integer :port
			end
		end
		
		# Create the modules table if missing
		if !settings.orm.table_exists? :modules
			settings.orm.create_table :modules do
				String :uuid, :unique => true
				String :nexus
				String :name
				String :room
				String :type
			end
		end
		
		# Create the callbacks table if missing
		if !settings.orm.table_exists? :callbacks
			settings.orm.create_table :callbacks do
				String :uuid
				String :event
				String :class
				String :method
			end
		end
		
		# generate a secret key if one doesn't exist
		
		# Register the routes for each currently installed app
		settings.orm[:apps].each do |app_info|
			app = Module.const_get(app_info[:object])
			dir = app_info[:dir]
			register_routes(app, dir)
		end

		# Provide a reference to the app installation method
		set :install, self.method(:install)
		
	end
	
	helpers do
	
		def render_admin(message=nil)
			erb :admin, :locals => {:app_count => settings.orm[:apps].count,
									:nexus_count => settings.orm[:nexus].count,
									:callbacks => settings.orm[:callbacks],
									:modules => settings.orm[:modules],
									:message => message}
		end

		def render_manage_apps(message=nil)
			erb :manage_apps, :locals => {:apps => settings.orm[:apps],
						      :message => message}
		end
		

	end
	
	post '/event_reciever' do
		event = JSON.parse request.body.read
		type = event['type']
		uuid = event['uuid']
		data = event['data']
		#hmac = event['hmac']
		if type == "NexusReport"
			port = event['port']
			settings.orm[:nexus].replace(
				:uuid => uuid,
				:ip => request.ip,
				:port => port
			)
			data.each do |k, v|
				settings.orm[:modules].replace(
					:uuid => k,
					:nexus => uuid,
					:name => v['name'],
					:room => v['room'],
					:type => v['type']
				)
			end
		elsif type == "EventReport"
			settings.orm[:callbacks].where(:uuid => uuid).each do |callback|
				capture = /#{callback[:event]}/.match data
				if capture != nil
					app_class = Module.const_get(callback[:class])
					app_class.method(callback[:method].to_sym).(settings.orm, uuid, capture)
				end
			end
		end
		status 200
	end

	post '/install_app' do

		# offer to install gems required by the app (file, or class property)
		# detect if app is already installed and offer an upgrade

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
					FileUtils.mkdir_p "./apps/"+path[0..path.size-2].join("/")
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
			load "./apps/#{app_dir}/app.rb"
			class_name = (/class \w+/.match File.read("./apps/#{app_dir}/app.rb")).to_s.split(" ")[1]
			app = Module.const_get(class_name)
			name = app.class_variable_get(:@@name)
			version = app.class_variable_get(:@@version)
			description = app.class_variable_get(:@@description)
			settings.install.(app, app_dir)
			settings.orm[:apps].insert(
				:name => name,
				:version => version,
				:description => description,
				:object => class_name,
				:dir => app_dir
			)

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

        ( status 404; return ) if settings.orm[:apps].where(:object => app_obj).count == 0
        app_info = settings.orm[:apps].where(:object => app_obj).first
        app = Module.const_get(app_info[:object])

		begin
			FileUtils.rm_rf("./apps/" + app_info[:dir])
			app.remove_tables(settings.orm) if app.methods.include? :remove_tables
			settings.orm[:callbacks].where(:class => app_info[:object]).delete
			app_info.delete
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
		
        ( status 404; return ) if settings.orm[:apps].where(:object => app_obj).count == 0
        app_info = settings.orm[:apps].where(:object => app_obj).first
        app = Module.const_get(app_info[:object])

		erb :app_detail, :locals => {:app_info => app_info} do
			erb :options, :views => "./apps/#{app_info[:dir]}/views",
						  :layout_options => { :views => 'views'} if File.exists?("./apps/#{app_info[:dir]}/views/options.erb")
		end

	end

	get '/' do
		tiles = []
		settings.orm[:apps].each do |app_info|
			app = Module.const_get(app_info[:object])
			if app.methods.include? :tile
				tile = app.tile(settings.orm)
				tile[:object] = app_info[:name]
				tiles << tile
			end
		end
		erb :dashboard, :locals => {:tiles => tiles}
	end
	
	get '/manage_apps' do
		render_manage_apps
	end
	
	get '/admin' do
		render_admin
	end

	# Clear the modules table
	get '/clear_modules' do
	
		message = nil
		begin
			settings.orm[:modules].delete
			message = {
				:class => "alert-success",
				:title => "Cleared:",
				:detail => "the modules table has been cleared"
			}
		rescue => e
			message = {
				:class => "alert-danger",
				:title => "Failed:",
				:detail => e.to_s
			}
		end

		render_admin message		# render_message?

	end

	# Clear the modules and nexus tables
	get '/clear_nexus' do

		message = nil
		begin
			settings.orm[:modules].delete
			settings.orm[:nexus].delete
			message = {
				:class => "alert-success",
				:title => "Cleared:",
				:detail => "the modules and nexus tables have been cleared"
			}
		rescue => e
			message = {
				:class => "alert-danger",
				:title => "Failed:",
				:detail => e.to_s
			}
		end

		render_admin message		# render_message?

	end

	# Download a zip of an application
	get '/download_zip/:app_object' do |app_obj|

		app = settings.orm[:apps].where(:object => app_obj).first
		( status 404; return ) if !app
		
		dir = app[:dir]
		tmp_file = "/tmp/#{dir}.zip"
		File.delete(tmp_file) if File.exists? tmp_file
		
		# Get all paths in dir, remove directories, strip apps/
		app_files = (Dir.glob("./apps/#{dir}/**/*").reject { |entry| File.directory?(entry) }).map! { |s| s = s.split("apps/")[1] }
		Zip::OutputStream.open(tmp_file) do |zip_stream|
			app_files.each do |file|
				zip_stream.put_next_entry(file)
				File.open("./apps/"+file) { |f| zip_stream << f.read}
			end
		end

		send_file tmp_file, :type => 'application/zip', :disposition => 'attachment', :filename => "#{dir}.zip"
	end
	
	# Generate a nexus config file specific to this TerraMod installation
	post '/generate_config' do
		# need to set a bind port, terramod secret, terramod IP
		#modules = JSON.parse request.body.read
		#puts modules
	end

	# Rename a hardware module by updating the nexus's config file
	post '/rename_module' do
		mod = JSON.parse request.body.read
		uuid = mod['uuid']
		name = mod['name']
		room = mod['room']
		#get '/rename/:module_uuid/:new_name/:new_room' do |module_uuid, new_name, new_room|
			#begin
				#nexus_uuid = settings.db.execute("SELECT nexus_uuid FROM Modules WHERE uuid=?;", [module_uuid])[0]
			#rescue
				#status 404
				#return
			#end
			#if !nexus_uuid
				#return "disconnected nexus"
			#end
			#nexus_ip = settings.db.execute("SELECT ip FROM Nexus WHERE uuid=?;", nexus_uuid)[0][0]
			#resp = Net::HTTP.get(URI.parse(URI.encode("http://#{nexus_ip}/rename/#{module_uuid}/#{new_name}/#{new_room}")))
			#return resp
		#end
	end
	
end
