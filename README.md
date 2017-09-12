I'm not sure if anyone on here uses http://parseplatform.org as their backend, but coming from mobile development it is my favorite option. It has the benefit of being open-sourced so you can host it on your own or if you don't want to put up with that hassle you can look at out-of-the-box commercial solutions like [back4app](http://back4app.com).

 I've been working on ways to implement it into [Floopcity](https://devforum.roblox.com/t/floopcity-beta-release-coming-soon/47892), which means I've had to give up on all of the iOS objective-c libraries I am used to having at my disposal. 

It's not much yet and I've only put in a few nights of work on it, but I figured I would share a post of my thoughts so far. It uses [HttpService](http://wiki.roblox.com/index.php?title=API:Class/HttpService), [Priority Queues](http://wiki.roblox.com/index.php?title=Libraries_and_Samples/Priority_Queue), and Stravant's [Signal](https://devforum.roblox.com/t/custom-events/9631/6) module.

As of right now, there are calls functions for GET, POST, CloudCode function calls (a Parse Server JS feature), and for enqueuing batch REST calls. There isn't too much, or any, error handling (minus one pcall) and its expected that the module is used via RemoteEvents to another script which requires the module (that's how I am using it).

Without further ado:

# ParseServer on ROBLOX

 **Using http://docs.parseplatform.org/rest/guide** 



To send a batch REST request to Parse it needs to have a **url**, **data**, **content-type**, and **header**. We will be using `HTTPService:PostAsync(…)` with compression set to `false`.

URL:

```Lua
local url = string.format("%s/batch", ParseServer.Url)
```



The data is more complex for a batch REST request. Each individual operation requests need to have a **method**, **path**, and **body**.  In order to send successfully, the operations need to be structured as nested arrays within the **request** table. This table is to be encoded into JSON before making the final batch request.

Before JSON:

```Lua
local body = {
			requests = {
				{
					method = "POST",
					path = "/classes/_User",
					body = {
						username = "newuser1",
						password = "password1"
					} 
				},
				{
					method = "POST",
					path = "/classes/_User",
					body = {
						username = "newuser2",
						password = "password1"
					} 
				}
			}	
		}
```



After JSON:

```Lua
local newbody = HttpService:JSONEncode(body)
>> print(body)

{
  "requests":
  [
    {
      "body":
      {
        "password":"password",
        "username":"newuser1"
      },
      "method":"POST",
      "path":"/classes/_User"
    },
    {
      "body":
      {
        "password":"password","username":"newuser2"
      },
      "method":"POST",
      "path":"/classes/_User"
    }
  ]
}
```



For our POST request we will be sending the data with the content-type `Enum.HttpContentType.ApplicationJson` and we will not be compressing this data (`false`).

```Lua
... Enum.HttpContentType.ApplicationJson, false ...
```



Header:

```Lua
	local header = {
		["X-Parse-Application-Id"] = ParseServer.AppId,
		["X-Parse-REST-API-Key"] = ParseServer.RESTKey,
  		["X-Parse-Master-Key"] = ParseServer.MasterKey -- Optional. Less secure.
	}
```



Sending it all:

```Lua
local post = HttpService:PostAsync(url, newbody, Enum.HttpContentType.ApplicationJson, false, header)
```



Sample response:

```Lua
[
	{
  		"error":
  		{
    		"code":202,
    		"error":"Account already exists for this username."
  		}
	},
	{
  		"success":
  		{
    		"objectId":"EpAscYOD3A",
    		"createdAt":"2017-08-10T07:16:16.360Z",
    		"sessionToken":"r:525c5aa1de1873febcc73cc61b741a82"
  		}
	}
]
```



Some tested batch operations that demonstrate use. Check the [guide](http://docs.parseplatform.org/rest/guide) for more:

## <u>POST</u>

**Working POST for Batch REST**

```lua
{
	method = "POST",
	path = "/classes/_User",
	body = {
		username = "newuser2",
		password = "password"
	} 
}
```



# <u>PUT</u>

**Working PUT for Batch REST**

*NEED TO KNOW ObjectId*

```lua
{
	method = "PUT",
	path = "/classes/_User/HiyuVD16ra",
	body = {
  		username = "me23"
	}
}
```



# <u>GET</u>

**Using GET without an ObjectId**

```lua
{
	method = "GET",
	path = "/classes/_User",
	body = {
		where = {
			username = "me23"
		}
	}
}
```



**Using GET with an ObjectId**

```lua
{
	method = "GET",
	path = "/classes/_User/HiyuVD16ra",
	body = {
	}
}

```



**Using GET with $or**

*More posibilities with contraints: http://docs.parseplatform.org/rest/guide/#query-constraints*

```lua
{
	method = "GET",
	path = "/classes/_User",
	body = {
		where = {
			["$or"] = {
				{
					username = "me2"
				},
				{
					username = "me23"
				}
			}
		}
	}
}
```



**Using GET with $and**

```lua
{
	method = "GET",
	path = "/classes/_User",
	body = {
		where = {
			["$and"] = {
				{
					username = "me23"
				},
				{
					test = "hi"
				}
			}
		}
	}
}
```



**Using GET to count object in a class**

```lua
{
	method = "GET",
	path = "/classes/_User",
	body = {
		count = 1
		limit = 0
	}
}
```



**Using GET to count 'specific' objects in a class**

```lua
{
	method = "GET",
	path = "/classes/_User",
	body = {
		count = 1
		limit = 0
		where = {
			test = "hi"
		}
	}
}
```



## <u>DELETE</u>

**Working DELETE for Batch REST**

```lua
{
	method = "DELETE",
	path = "/classes/_User/HiyuVD16ra",
	body = {
	}
}
```



# Module

 **As it stands right now** 

The ParseServer is a module class with internal variable `Keys` needed to communicate with the server. They are used by the publically accessible (upon `require`) functions.

```Lua
local HttpService = game:GetService("HttpService")
local PriorityQueue = require(303863449)
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

ParseServer.timeOut = 10
ParseServer.batchLimit = 50 -- Parse has a max of 50 requests allowed per batch

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

-- Pops batchLimit number of requests from PriorityQueue, bundles them into a requests table for ParseServer:BatchPost(), and then fires the responses and timestamps back to whoever is listening for a reponse (the senders)
function ParseServer:ExecuteQueue()
	local requests = {}
	local timestamps = {}
	local signals = {}
	
	local queueSize = ParseServer.Queue:Size()
	if queueSize > ParseServer.batchLimit then queueSize = ParseServer.batchLimit end -- Limited requests per batch
	
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

-- Requests will be sent every timeOut seconds, or when the batchLimit is hit.
game:GetService("RunService").Heartbeat:Connect(function(step)
	stepTime = stepTime + step
	
	local queueSize = ParseServer.Queue:Size()
	if (queueSize >= ParseServer.batchLimit or stepTime >= ParseServer.timeOut) and not (batching or queueSize == 0) then
		stepTime = 0
		batching = true		
		local success = pcall(ParseServer:ExecuteQueue())
		batching = false
	end
end)

return ParseServer
```

### Sample Implementation

The following implementation is more for static content, where you expect an "immediate" response. It also does not take advantage of any functions like `NestedTable()` or `MakeRequest()`.

```Lua
local ParseServer = require(script.ParseServer)

local get = ParseServer:Get("_User")
print(get)

local body = {
	username = "username",
	password = "password"
}
local post = ParseServer:Post("_User", body)
print(post)

local rawContent = {
  	action = "createRoom"
	username= "polarpanda16"
}
local cloud = ParseServer:CloudCode("batch", rawContent)
print(cloud)

local requests = {
	{
		method = "POST",
    	path = "/classes/_User",
    	body = {
      		username = "newuser1",
      		password = "password"
   		} 
  	},
  	{
   		method = "POST",
    	path = "/classes/_User",
    	body = {
      		username = "newuser2",
      		password = "password"
    	} 
  	}
}
local batchPost = ParseServer:BatchPost()
print(batchPost)
```

### Batch Requests Across Scripts

In a more realistic setup, the following two scripts simulate the normal experience you would want to incorporate into your game. I have helper functions for putting pieces of the individual requests together, but you are still expected to know the type of request (i.e., "GET," "POST," "PUT," etc.) and the path (ex: "/classes/_User").

##### Script 1:

```Lua
local ParseServer = require(script.ParseServer)

local count = 1
local limit = 0
local where = {
	username = "me23",
	test = "hi"
}
local nested1 = ParseServer:MakeNested("count", count, "limit", limit, "where", where) -- Make the body of the request

local request1 = ParseServer:MakeRequest("GET", "/classes/_User", nested1) -- Make the request
local response, timestamp = ParseServer:EnqueueRequest(request1):wait() -- Enqueue the request and wait for the signal to fire. The signal is returned by EnqueueRequest and fired when the batch is POSTed and recieves a response from the server.

-- Handle the response
local HttpService = 
print(string.format("\nResponse:%s\nTimestamp:%s",, game:GetService("HttpService"):JSONEncode(response), timestamp))
```

##### Script 2:

```Lua
local ParseServer = require(script.ParseServer)

wait(1) -- Artificial delay between first response in Script 1
local username = "username1"
local password = "password1"
local nested2 = ParseServer:MakeNested("username", username, "password", password)

local request2 = ParseServer:MakeRequest("POST", "/classes/_User", nested2)
local response, timestamp = ParseServer:EnqueueRequest(request2):wait()

-- Handle the response
local HttpService = game:GetService("HttpService")
print(string.format("\nTimestamp:%s\nResponse:%s", timestamp, HttpService:JSONEncode(response)))

```

### The Cloud Code

Since the ParseServer supports cloud code calls, the Parse App must be correctly configured for Cloud Functions and have a `main.js` to receive/handle them. For example, this would recieve and handle the call from the sample implementation above:

```javascript
var functions = {};

functions["createRoom"] = function(request, response) {
  //response.success("Hello world!");

  var username = request.params.username

    if (!username) {
        response.error("A Room must have an owner");
    } else {
        if (!(/^\w+$/i.test(username))){
            response.error("Only letters and numbers, please.");
        }
        var query = new Parse.Query("Group");
        query.equalTo("name", username);
        query.first({
            success: function(object) {
                if (object) {
                    response.error("A Room with this owner exists.");
                } else {
                    createPlayerRoom(request.params);
                    response.success();
                }
            },
            error: function(error) {
                response.error("Could not validate Uniqueness");
            }
        });
    }
};

Parse.Cloud.define("batch", function(request, response) {
  //response.success("Hello world!");
  var action = request.params.action;
  functions[action](request, response);
  response.success();
});

createPlayerRoom = function(data) {
    var RoomClass = Parse.Object.extend("Room");
    var room = new RoomClass();

    room.set("creatorUsername", data.username);
    room.save(null,{
      success:function(room) {
        response.success(room);
      },
      error:function(error) {
        response.error(error);
      }
    });
}
```
## Actual Use Case:

So, I've provided a lot of dry documentation (and maybe [DRY](https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=2&cad=rja&uact=8&ved=0ahUKEwie4ovbh9XVAhWJgFQKHa14BFAQFggoMAE&url=https%3A%2F%2Fen.wikipedia.org%2Fwiki%2FDon%2527t_repeat_yourself&usg=AFQjCNFsoUrJ4BbE-8Rs74udgMfeGioOFQ)) but where would you actually use this. Well, I'll show you how I am using it right now although I've just began with it and know I'll be adding on more capabilities (especially ones that deal with avoiding throttling limits).

I'm using it to keep track of player rooms (yay apartment systems!) across servers. Its at a very preliminary stage, but I think you'll see where I'm going with it.

In my first script, within `ServerScriptService` I handle batching a single request to fetch a list of user rooms and then I send that out to all of my clients with a remote event that updates local UIs in a second script. 

```Lua
-- A remote event that my clients are listening for
local ParseEvents = ClientNetwork:FindFirstChild("ParseEvents")
local ServerRefreshedEvent = ParseEvents:FindFirstChild("ServerRefreshedEvent")

-- Where I have this script and my ParseServer module
local ServerScriptService = game:GetService("ServerScriptService")
local ServerTasks = ServerScriptService:FindFirstChild("ServerTasks")
local ParseTasks = ServerTasks:FindFirstChild("ParseTasks")

-- For heartbeat
local RunService = game:GetService('RunService')

-- the ParseServer module, but I change the TimeOut time for testing purposes
local ParseServer = require(ParseTasks:FindFirstChild("ParseServer"))
ParseServer.TimeOut = 20

local refreshing = false -- Since I am using heartbeat I do not want to enqueue more than one GET when its time
local checkTime = 30 -- How often I'll GET room objects from the server

local lastResponse = nil -- Used to keep track of when responses have not changed

-- Checks if tables are equal. I think I got this off of StackOverflow or something (thanks to whoever wrote it!)
local function equals(o1, o2, ignore_mt)
    if o1 == o2 then return true end
    local o1Type = type(o1)
    local o2Type = type(o2)
    if o1Type ~= o2Type then return false end
    if o1Type ~= 'table' then return false end

    if not ignore_mt then
        local mt1 = getmetatable(o1)
        if mt1 and mt1.__eq then
            --compare using built in method
            return o1 == o2
        end
    end

    local keySet = {}

    for key1, value1 in pairs(o1) do
        local value2 = o2[key1]
        if value2 == nil or equals(value1, value2, ignore_mt) == false then
            return false
        end
        keySet[key1] = true
    end

    for key2, _ in pairs(o2) do
        if not keySet[key2] then return false end
    end
    return true
end

local function refreshRooms()
  	-- Order based on decending values of a visits field
	local order = "-visits" 
	local nested1 = ParseServer:MakeNested("order", order)

	local request1 = ParseServer:MakeRequest("GET", "/classes/Room", nested1)
	local response, timestamp = ParseServer:EnqueueRequest(request1):wait()
	
	
	local success = response.success
	if not success then
    	-- Request failed: skip the wait time and try again
		refreshing = false
		return
	end
	local sameAsLastResponse = equals(response, lastResponse)
	if not sameAsLastResponse then
    	-- Request success and new data in response: send to clients
		lastResponse = response
		ServerRefreshedEvent:FireAllClients(response, timestamp)
	end
	
  	-- Calculate the wait time (approx 30 sec) to account for however long the request took
	local timeTaken = os.difftime(os.time(), timestamp)
	
	wait(checkTime - timeTaken)
	refreshing = false
end

local count = 0
local upperBound = checkTime

-- Only check ones count reaches the upperBound, or checkTime in this case
RunService.Heartbeat:connect(function(step)
	if (count < upperBound or refreshing) then
		count = count + step
		return
	elseif not refreshing then
		count = count - upperBound
		refreshing = true
	    refreshRooms()
	end
end)
```

My server script uses the ParseServer module, but checks for dropped/failed requests, or requests where nothing on the server has changed and therefore where it would be pointless to update the clients.

In a LocalScript in a StarterGui object:

```lua
-- Once again where my remote event is located. Fired by the server script above
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerRooms = ReplicatedStorage:FindFirstChild("PlayerRooms")
local ClientNetwork = ReplicatedStorage:FindFirstChild("ClientNetwork")
local ParseEvents = ClientNetwork:FindFirstChild("ParseEvents")
local ServerRefreshedEvent = ParseEvents:FindFirstChild("ServerRefreshedEvent")

-- Where I have this script and my ParseServer module
local ServerScriptService = game:GetService("ServerScriptService")
local ServerTasks = ServerScriptService:FindFirstChild("ServerTasks")
local ParseTasks = ServerTasks:FindFirstChild("ParseTasks")

--  I have a saved GUI object that I use as a template for each row
local Listing = PlayerRooms:FindFirstChild("Listing")
local PlayerRoomsGui = script.Parent:FindFirstChild("PlayerRooms")

-- Little helper function
local function setObjectText(parent, objectName, text)
	local object = parent:FindFirstChild(objectName)
	object.Text = tostring(text)
end

ServerRefreshedEvent.OnClientEvent:Connect(function(response, timestamp)
    -- I have a table using UIListLayout that I want to clear, except for the header object
    -- Ideally, this would also check against the new data and only update/destroy data accordingly. In a 'cached' type of scenario
	for _, child in ipairs(PlayerRoomsGui:GetChildren()) do
		if (child:IsA("Frame") and child.Name ~= "Header") then
			child:Destroy()
		end
	end

    -- I'd rather type results.field than response.success.results.field
	local results = response.success.results
	
    -- Create new rows in table
	for index, result in ipairs(results) do
		local newListing = Listing:Clone()
		setObjectText(newListing, "Owner", result.creatorUsername)
		setObjectText(newListing, "Name", result.roomName)
		setObjectText(newListing, "Online", #result.users)
		setObjectText(newListing, "Visits", result.visits)
		setObjectText(newListing, "Updated", result.playerUpdated)
		setObjectText(newListing, "Rank", "NA")
		newListing.Parent = PlayerRoomsGui
		newListing.LayoutOrder = index -- To be changed
	end
end)
```

Of course I do not put a limit on how many objects are returned from the GET request, but this would be needed and is pretty easy to do. I only have placeholder data right now so I ignored the step.