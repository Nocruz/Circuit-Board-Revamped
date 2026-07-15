--[[ INTERACTIONS
		This modules handles Client-Server communications
		in both ways. It runs all validations, and then
		delegates the response to the controller.
]]

-- Requires and Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Safezones = require(script.Parent.Safezones)
local Permissions = require(script.Parent.Permissions)
local GatesHandler = require(ServerScriptService.GateService.Handlers.GatesHandler)
local GridService = require(ReplicatedStorage.GridService)

-- References
local eventsFolder = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Events")
local queriesFolder = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Queries")

-- Constants
local simulatedLag: number = 0.4

-- ----------------------------- --------- PARAMETER RESOLUTION ---------- -----------------------------

export type TParameter = "GateID" | "Action" | "CFrame" | "string" | "AttributesTable" | "SaveIdentifier" | "GateIDTable"

local ParameterSolver: { [TParameter]: (... any) -> (boolean, string | any) } = {
	["GateID"] = function(gateID: number)
		if not gateID or type(gateID) ~= "number" then
			return false, "Invalid parameters! Gate ID was not a number"
		end
		local gate = GatesHandler.Get(gateID)
		if not gate then
			return false, "Invalid gate ID " .. tostring(gateID) .. ", gate is not registered"
		end
		return true, gate
	end,
	
	["Action"] = function(action: string)
		if not action or type(action) ~= "string" then
			return false, "Invalid parameters! Action was not a string"
		end
		if not Permissions.IsValidAction(action) then
			return false, "Invalid action! Check with a mod"
		end
		return true, action
	end,
	
	["CFrame"] = function(cframe: CFrame)
		if not cframe or typeof(cframe) ~= "CFrame" then
			return false, "Invalid parameters! CFrame was not a CFrame"
		end
		if cframe.X ~= cframe.X or cframe.Y ~= cframe.Y or cframe.Z ~= cframe.Z then
			return false, "Invalid position! NaN values?"
		end
		if cframe.Y < -0.005 then
			return false, "Invalid position! Too low!"
		end
		if Safezones.IsGateInSafezone(cframe.Position, Vector3.new(2, 1, 2)) then
			return false, "Invalid position! Too close to a safezone"
		end
		return true, GridService.fromCFrame(cframe)._cframe
	end,
	
	["string"] = function(p_string: string)
		if not p_string or type(p_string) ~= "string" then
			return false, "Invalid parameters! string was not a string"
		end
		return true, p_string
	end,
	
	["AttributesTable"] = function(p_table: { any })
		if not p_table or type(p_table) ~= "table" then
			return false, "Invalid parameters! AttributesTable was not a table"
		end
		
		for name, value in pairs(p_table) do
			if type(name) ~= "string" then
				return false, "Invalid parameters! Check with a mod"
			end
		end
		
		return true, p_table
	end,
	
	["SaveIdentifier"] = function(iden: string)
		if not iden or type(iden) ~= "string" then
			return false, "Invalid parameters! Identifier was not a string"
		end
		local match = iden.match(iden, "^[%a_][%w _%-#()]*$")
		if match ~= nil then
			return true, iden
		else
			return false, "Invalid parameters! iden was not a valid identifier"
		end
	end,
	
	["GateIDTable"] = function(p_table: { any })
		if not p_table or type(p_table) ~= "table" then
			return false, "Invalid parameters! AttributesTable was not a table"
		end
		
		local seen = {}
		local ret = {}
		for idString in pairs(p_table) do
			local id = tonumber(idString)
			if id == nil then
				return false, "Invalid parameters! Check with a mod"
			end
			local gate = GatesHandler.Get(id)
			if not gate then
				return false, "Invalid gate ID " .. tostring(id) .. ", gate is not registered"
			end
			if seen[id] ~= nil then
				return false, "Tried to save same gate twice!"
			end
			table.insert(ret, gate)
			seen[id] = true
		end
		
		return true, ret
	end
}

-- ----------------------------- ----------- MODULE DEFINITION ----------- -----------------------------

local Interactions = {}

-- ----------------------------- --------------- COOLDOWNS --------------- -----------------------------

local QUERY_COOLDOWN = 0.05 -- seconds
local EVENT_COOLDOWN = 0.1 -- seconds
local LOAD_COOLDOWN = 3 -- seconds
local queryCooldowns: { [number]: true } = {}
local eventCooldowns: { [number]: true } = {}
local loadCooldowns:  { [number]: true } = {}

local function IsCooldowned(id: number, from: "Query" | "Event" | "Load"): boolean
	return
		if from == "Query" then queryCooldowns[id] ~= nil
		elseif from == "Event" then eventCooldowns[id] ~= nil
		else --[[from == "Load" then]] loadCooldowns[id] ~= nil
end

local function SetCooldown(id: number, duration: number, from: "Query" | "Event" | "Load")
	local cooldowns =
		if from == "Query" then queryCooldowns
		elseif from == "Event" then eventCooldowns
		else --[[from == "Load" then]] loadCooldowns
	
	if cooldowns[id] then return end
	
	cooldowns[id] = true
	task.delay(duration, function() cooldowns[id] = nil end)
end

-- ----------------------------- --------------- CREATION ---------------- -----------------------------

function Interactions.CreateQuery(name: string, parameterTypes: { TParameter }, successCallback: (... any) -> (boolean, string?))
	local query = queriesFolder:FindFirstChild(name)
	if query == nil then
		query = Instance.new("RemoteFunction")
		query.Name = name
		query.Parent = queriesFolder
	end
	
	query.OnServerInvoke = function(player: Player, ...): (boolean, string?)
		task.wait(simulatedLag)
		
		local parameters = { ... }
		
		if IsCooldowned(player.UserId, "Query") then
			print(player.Name .. " tried to query, but is still in cooldown")
			return false, "Too fast!"
		end
		SetCooldown(player.UserId, QUERY_COOLDOWN, "Query")
		
		if #parameters < #parameterTypes then
			warn("Player " .. player.Name .. " called a query with wrong parameter count")
			return false, "Invalid parameters! Check with a moderator"
		end
		
		local solvedParameters = {}
		for i, expectedType in ipairs(parameterTypes) do
			local success, result = ParameterSolver[expectedType](parameters[i])
			if not success then return false, result end
			
			solvedParameters[i] = result
		end
		
		return successCallback(player, unpack(solvedParameters))
	end
end

function Interactions.CreateEvent(name: string, parameterTypes: { TParameter }, successCallback: (... any) -> (boolean, string?))
	local event = eventsFolder:FindFirstChild(name)
	if event == nil then
		event = Instance.new("RemoteFunction")
		event.Name = name
		event.Parent = eventsFolder
	end
	
	event.OnServerInvoke = function(player: Player, ...): (boolean, string?)
		task.wait(simulatedLag)
		
		local parameters = { ... }
		
		if IsCooldowned(player.UserId, "Event") then
			print(player.Name .. " tried to execute an event, but is still in cooldown")
			return false, "Too fast!"
		end
		SetCooldown(player.UserId, EVENT_COOLDOWN, "Event")
		
		if #parameters < #parameterTypes then
			warn("Player " .. player.Name .. " called an event with wrong parameter count")
			return false, "Invalid parameters! Check with a moderator"
		end
		
		local solvedParameters = {}
		for i, expectedType in ipairs(parameterTypes) do
			local success, result = ParameterSolver[expectedType](parameters[i])
			if not success then return false, result end
			
			solvedParameters[i] = result
		end
		
		return successCallback(player, unpack(solvedParameters))
	end
end

function Interactions.CreateLoadEvent(name: string, parameterTypes: { TParameter }, successCallback: (... any) -> (boolean, string?))
	local event = eventsFolder:FindFirstChild(name)
	if event == nil then
		event = Instance.new("RemoteFunction")
		event.Name = name
		event.Parent = eventsFolder
	end
	
	event.OnServerInvoke = function(player: Player, ...): (boolean, string?)
		task.wait(simulatedLag)
		
		local parameters = { ... }
		
		if IsCooldowned(player.UserId, "Event") then
			print(player.Name .. " tried to execute an event, but is still in cooldown")
			return false, "Too fast!"
		end
		SetCooldown(player.UserId, LOAD_COOLDOWN, "Event")
		
		if #parameters < #parameterTypes then
			warn("Player " .. player.Name .. " called an event with wrong parameter count")
			return false, "Invalid parameters! Check with a moderator"
		end
		
		local solvedParameters = {}
		for i, expectedType in ipairs(parameterTypes) do
			local success, result = ParameterSolver[expectedType](parameters[i])
			if not success then return false, result end
			
			solvedParameters[i] = result
		end
		
		return successCallback(player, unpack(solvedParameters))
	end
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return Interactions
