using Diana
using JSON



data = JSON.parse(open(f->read(f,String),"CanvasAPIconfig.json"))


key = data["key"]
url = data["url"] * "/api/graphql"
client = GraphQLClient(url)
client.serverAuth("Bearer "*key)
client.headers(Dict("header"=>"value"))

query = """
	query MyQuery {
		allCourses {
			_id
    			name
			term{
			_id
			}
  		}
		}
	"""

r = client.Query(query)
c = JSON.parse(r.Data)
yearcourses = Dict()
for course in c["data"]["allCourses"]
	if haskey(yearcourses,course["term"]["_id"])
		yearcourses[course["term"]["_id"]][course["name"]] = course["_id"]
	else
		yearcourses[course["term"]["_id"]] = Dict(course["name"] => course["_id"])
	end
end

open("courseids.json","w") do f
	JSON.print(f,yearcourses)
end
