class QueryModule

	@@name		= "libquerymod"
	@@version	= "1.0"
	@@description	= "This library allows other applications to query module states, and exposes a web API so pages can query modules via AJAX."

	def self.routes
		return [{
				:verb => "get",
				:url => ":uuid",
				:method => QueryModule.method(:query_module)
			}
		]
	end

	def self.query_module(db, params)
		module_uuid = params[:uuid]
		begin
                        nexus_uuid = db.execute("SELECT nexus_uuid FROM Modules WHERE uuid=?;", [module_uuid])[0]
                rescue
                        return "module not found"
                end
		if !nexus_uuid
                        return "nexus not found"
                end
		nexus_ip = db.execute("SELECT ip FROM Nexus WHERE uuid=?;", nexus_uuid)[0][0]
		resp = Net::HTTP.get(URI.parse("http://#{nexus_ip}/query/#{module_uuid}"))
                return resp
	end
end
