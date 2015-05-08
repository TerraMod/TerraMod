#!/usr/bin/ruby
require 'sqlite3'
require 'lifx'

begin
	lifx = LIFX::Client.lan
	lifx.discover!
	
	db = SQLite3::Database.open('/home/pi/TerraMod/terramod.db')
	db.execute('UPDATE Lights SET credits=credits-1 WHERE credits>0;');
	labels = db.execute('SELECT label FROM Lights where credits<=0;')
	labels.flatten
	labels.each do |label|
		puts "label: #{label[0]}"
		lights = lifx.lights.with_label(label[0])
		puts "lights: #{lights}"
		lights.turn_off!
	end
	open('credit_log.log', 'a') do |log|
		log.puts "#{Time.now}"
		log.puts "\n"
	end
	db.close if db
rescue SQLite3::Exception => e
	open('credit_log.log', 'a') do |log|
		log.puts "#{Time.now}: "
		log.puts e
		log.puts "\n"
	end
	db.close if db
end
