class TerraMod < Sinatra::Application

	get "/", auth: user do
	end

	get "/404" do
	end
end
