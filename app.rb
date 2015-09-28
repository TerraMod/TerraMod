#!/usr/bin/env ruby

require 'sinatra'
require 'sequel'
require 'tilt/erb'

class TerraMod < Sinatra::Application

	configure :production do
		set :clean_trace, true
	end

	configure :development do

	end
end

require_relative 'util/authentication'
require_relative 'models/init'
