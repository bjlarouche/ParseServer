local HttpService = game:GetService("HttpService")
local PriorityQueue = require(1041400240)
local Signal = require(script.Signal)

local ParseServer = {}

ParseServer.Url = "https://parseapi.back4app.com"
ParseServer.AppId = "..."
ParseServer.AppName = "FloopCity"
ParseServer.MongoDBURI = "..."
ParseServer.ClientKey = "..."
ParseServer.JavascriptKey = "..."
ParseServer.NETKey = "..."
ParseServer.RESTKey = "..."
ParseServer.WebhookKey = "..."
ParseServer.FileKey = "..."
ParseServer.MasterKey = "..."

-- Reverse of default comparator
local function comparator(a, b)
	if a > b then
		return true
	else
		return false
	end
end

ParseServer.Queue = PriorityQueue.new(comparator)

ParseServer.TimeOut = 10
ParseServer.BatchLimit = 50 -- Parse has a max of 50 requests allowed per batch

local stepTime = 0
local batching = false

-- Returns a table where the odd parameters are the key and even parameters are the value
function ParseServer:MakeNested(...)
 	local packed = {...}
	local unpacked = {}
	
	for key, value in ipairs(packed) do
		if key % 2 == 1 then
			unpacked[packed[key]] = packed[key+1]
		end
	end
	return unpacked
end

-- Formats the request as Parse is expecting from REST for batching
function ParseServer:MakeRequest(method, path, body)
	local operation = {
		["method"] = method,
		["path"] = path,
		["body"] = body
	}
	return operation
end

-- Splits data up into needed URL formatting
local function makeBody(data)
	local body = ""
	for i,v in pairs(data) do
		body = body .. "&" .. i .. '=' .. HttpService:UrlEncode(v)
	end
	return body
end

-- Returns objects in the specified class
function ParseServer:Get(class)
	local url = string.format("%s/%s/%s", ParseServer.Url, "classes", class)
	
	local header = {
		["X-Parse-Application-Id"] = ParseServer.AppId,
		["X-Parse-REST-API-Key"] = ParseServer.RESTKey,
		--["X-Parse-Master-Key"] = ParseServer.MasterKey -- Optional. Less secure.
	}
		
	local get = HttpService:GetAsync(url, false, header)
	return get
end

-- Creates a new object of the given class with fields specified inn body
function ParseServer:Post(class, body)
	local url = string.format("%s/%s/%s", ParseServer.Url, "classes", class)


	local newbody = HttpService:JSONEncode(body)	
	
	local header = {
		["X-Parse-Application-Id"] = ParseServer.AppId,
		["X-Parse-REST-API-Key"] = ParseServer.RESTKey,
		--["X-Parse-Master-Key"] = ParseServer.MasterKey  -- Optional. Less secure.
	}
	
	local post = HttpService:PostAsync(url, newbody, Enum.HttpContentType.ApplicationJson, false, header)

	return post
end

-- Triggers functionId in the ParseServer's main.js with rawContent parameters for that function
function ParseServer:CloudCode(functionId, rawContent)
	-- functionId and actionId must be supported/handled by cloud code
	local url = string.format("%s/%s/%s", ParseServer.Url, "functions", functionId)
	local header = {
		["X-Parse-Application-Id"] = ParseServer.AppId,
		["X-Parse-REST-API-Key"] = ParseServer.RESTKey,
		--["X-Parse-Master-Key"] = ParseServer.MasterKey  -- Optional. Less secure.
	}
	
	local body = makeBody(rawContent)
	
	local post = HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationUrlEncoded, false, header)
	return post
end

-- POSTs batch table of requests and returns table of responses
function ParseServer:BatchPost(requests)
	local url = string.format("%s/batch", ParseServer.Url)
	
	local body = {
		["requests"] = requests	
	}
	
	local newbody = HttpService:JSONEncode(body)
	
	local header = {
		["X-Parse-Application-Id"] = ParseServer.AppId,
		["X-Parse-REST-API-Key"] = ParseServer.RESTKey,
		["X-Parse-Master-Key"] = ParseServer.MasterKey -- Optional. Less secure.
	}
	
	local post = HttpService:PostAsync(url, newbody, Enum.HttpContentType.ApplicationJson, false, header)
	return post
end

-- Adds a request to the PriorityQueue based on timestamp (oldest = highest)
function ParseServer:EnqueueRequest(request)
	local signal = Signal.Create()	
	local timestamp = os.time()
	
	local queueRequest = {
		["request"] = request, 
		["signal"] = signal,
		["timestamp"] = timestamp,
	}	
	
	ParseServer.Queue:Add(queueRequest, timestamp)
	
	return signal
end

-- Pops BatchLimit number of requests from PriorityQueue, bundles them into a requests table for ParseServer:BatchPost(), and then fires the responses and timestamps back to whoever is listening for a reponse (the senders)
function ParseServer:ExecuteQueue()
	local requests = {}
	local timestamps = {}
	local signals = {}
	
	local queueSize = ParseServer.Queue:Size()
	if queueSize > ParseServer.BatchLimit then queueSize = ParseServer.BatchLimit end -- Limited requests per batch
	
	for i=1, queueSize do
		local queueRequest = ParseServer.Queue:Pop()
		table.insert(requests, queueRequest.request)
		table.insert(signals, queueRequest.signal)
		table.insert(timestamps, queueRequest.timestamp)
	end
	
	local batchResponse = ParseServer:BatchPost(requests)
	local responseTable = HttpService:JSONDecode(batchResponse)
	
	for i=1, #responseTable do
		signals[i]:fire(responseTable[i], timestamps[i])
	end
	return true
end

-- Requests will be sent every stepTime seconds, or when the BatchLimit is hit.
game:GetService("RunService").Heartbeat:Connect(function(step)
	stepTime = stepTime + step
	
	local queueSize = ParseServer.Queue:Size()
	if (queueSize >= ParseServer.BatchLimit or stepTime >= ParseServer.TimeOut) and not (batching or queueSize == 0) then
		stepTime = 0
		batching = true		
		local success = pcall(ParseServer:ExecuteQueue())
		batching = false
	end
end)

-- Forces queue to execute when server is ending
game.OnClose = function()
	stepTime = 0
	batching = true		
	local success = pcall(ParseServer:ExecuteQueue())
	batching = false
end

return ParseServer