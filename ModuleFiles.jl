using JSON
using Diana
using HTTP
using Dates

touch("errors.txt")

canvasformat = DateFormat("y-m-dTH:M:S.sZ")

function robustdownload(url,path,filename)
	mkpath(path)
	println(filename)
	try download(url,path * filename)
	catch e
		print("failed download "* path * filename * "(" * url * ") \nTrying Again...")
		sleep(30)
		try download(url,path * filename)
		catch e
			nothing
			print("failed download "* path * filename * "(" * url * ") \n Skipping, Please Download Manually")
			open("errors.txt","a") do f
				write(f,"failed download "* path * filename * "(" * url * ")")
			end
		end
	end
end

function linkheaderparser(linkheader)
	pairs = Tuple(split(linkheader,","))
	pairs = map(x -> split(x,";"),pairs)
	d = Dict()
	for kv in pairs
		d[kv[2]] = kv[1]
	end
	replace(kv -> SubString(kv[1],7,length(kv[1]) - 1) => SubString(kv[2],2,length(kv[2]) - 1) ,d)
end


function restresponse(url,headers)
	r = HTTP.get(url,headers)
	d = linkheaderparser(HTTP.header(r,"Link"))
	if haskey(d,"next")
		return [JSON.parse(String(r.body)); restresponse(d["next"],headers)]
	end
	return JSON.parse(String(r.body))
end


function folderfilesdownload(folderid,path,usr)
	files = restresponse(urlrest * "folders/" * folderid * "/files", usr)
	for file in files
		if file["locked"]
			println("Locked:"* file["filename"])
		elseif isfile(path * file["filename"]) && Dates.unix2datetime(stat(path * file["filename"]).mtime) > DateTime(file["updated_at"][1:end-1])
			println("Downloaded: " *  file["filename"])
		else
			robustdownload(file["url"],path,file["filename"])
		end
	end
	print("/")
end

function foldersubfolderdownload(folderid,path,usr)
	folderfilesdownload(folderid,path,usr)
	folders = restresponse(urlrest * "folders/" * folderid * "/folders",usr)
	for folder in folders
		foldersubfolderdownload(string(folder["id"]),path * folder["name"] *"/",usr)
	end
end

function getrootfold(url,courseid,usr)
	foldlist = restresponse(url * "courses/" * courseid * "/folders",usr)
	for item in foldlist
		if item["position"] == nothing
			return string(item["id"])
		end
	end
end

data = JSON.parse(open(f->read(f,String),"CanvasAPIconfig.json"))

key = data["key"]

courseid = data["courseid"]
if haskey(data,"downloadpath")
	downloadpath = data["downloadpath"]
	if last(downloadpath,1) != "/"
		downloadpath = downloadpath * "/"
	end
else
	downloadpath = "./"
end
urlrest = data["url"] * "/api/v1/"
usr = Dict("Authorization" => "Bearer " * key)

rootfoldid = getrootfold(urlrest,courseid,usr)

println("Starting Downloads")

foldersubfolderdownload(rootfoldid,downloadpath,usr)

println("")
