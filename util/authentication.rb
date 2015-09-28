class TerraMod < Sinatra::Application
	set :sessions => true

	register do
		def auth(type)
			#condition do
			redirect '/login' unless send("#{type}_authenticated?")
			#end
		end
	end

	helpers do
		def user_authenticated?
			@user != nil
		end

		def admin_authenticated?
			@user != nil && @user.admin
		end
	end

	before do
		@user = User.from_session_id(session[:id])# user who has session id present in active sessions
	end

	post "/login" do
		session[:id] = User.authenticate_sessions(params).id
	end

	get "/logout" do
		@user.destroy_session(session[:id])
	end

	#get "/test", auth: admin do
end
