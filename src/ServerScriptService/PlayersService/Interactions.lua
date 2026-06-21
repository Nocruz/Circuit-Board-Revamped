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

-- ----------------------------- --------- PARAMETER RESOLUTION ---------- -----------------------------

export type TParameter = "GateID" | "Action" | "CFrame"

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
		if Safezones.IsGateInSafezone(cframe.Position, Vector3.new(2, 1, 2)) then
			return false, "Invalid position! Too close to a safezone"
		end
		return true, GridService.fromCFrame(cframe)._cframe
	end
}

-- ----------------------------- ----------- MODULE DEFINITION ----------- -----------------------------

local Interactions = {}

-- ----------------------------- --------------- COOLDOWNS --------------- -----------------------------

local QUERY_COOLDOWN = 0.05 -- seconds
local EVENT_COOLDOWN = 0.1 -- seconds
local playerCooldowns: { [number]: true } = {}

local function IsCooldowned(id: number): boolean
	return playerCooldowns[id] ~= nil
end

local function SetCooldown(id: number, duration: number)
	if playerCooldowns[id] then return end
	
	playerCooldowns[id] = true
	task.delay(duration, function() playerCooldowns[id] = nil end)
end

-- ----------------------------- ----------- QUERY PERMISSIONS ----------- -----------------------------

function Interactions.CreateQuery(name: string, parameterTypes: { TParameter }, successCallback: (... any) -> (boolean, string?))
	local query = queriesFolder:FindFirstChild(name)
	if query == nil then
		query = Instance.new("RemoteFunction")
		query.Name = name
		query.Parent = queriesFolder
	end
	
	query.OnServerInvoke = function(player: Player, ...): (boolean, string?)
		local parameters = { ... }
		
		if IsCooldowned(player.UserId) then
			print(player.Name .. " tried to query, but is still in cooldown")
			return false, "Too fast!"
		end
		SetCooldown(player.UserId, QUERY_COOLDOWN)
		
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

-- ----------------------------- ------------ EVENT EXECUTION ------------ -----------------------------

function Interactions.CreateEvent(name: string, parameterTypes: { TParameter }, successCallback: (... any) -> (boolean, string?))
	local event = eventsFolder:FindFirstChild(name)
	if event == nil then
		event = Instance.new("RemoteFunction")
		event.Name = name
		event.Parent = eventsFolder
	end
	
	event.OnServerInvoke = function(player: Player, ...): (boolean, string?)
		local parameters = { ... }
		
		if IsCooldowned(player.UserId) then
			print(player.Name .. " tried to execute an event, but is still in cooldown")
			return false, "Too fast!"
		end
		SetCooldown(player.UserId, EVENT_COOLDOWN)
		
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
