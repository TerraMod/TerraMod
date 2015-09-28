class TerraMod < Sinatra::Application

	#
	# TerraMod routes for application management
	#

	get "/apps", auth: user do

	end

	post "/install", auth: user do

	end

	post "/remove", auth: user do

	end

end
