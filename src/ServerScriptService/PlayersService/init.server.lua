--[[ PLAYERS SERVICE
		Exposes events to cross the Server-Client boundary.
		Handles Permissions, Cooldowns, Filtering and Input sanitization.    
]]

-- Requires and Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local Permissions = require(script.Permissions)
local Interactions = require(script.Interactions)

local GateService = require(ServerScriptService.GateService)
local Connections = require(ServerScriptService.GateService.Connections)
local GatesHandler = require(ServerScriptService.GateService.Handlers.GatesHandler)

-- References
local gatesFolder = Workspace:FindFirstChild("Gates")
assert(gatesFolder, "No Gates folder under Workspace!")

-- ----------------------------- --------- PLAYER LIFETIME EVENTS -------- -----------------------------

local TIME_TO_DESTROY_GATES_AFTER_LEAVING = 5 * 60 -- 5 minutes
local destroyAllGatesTimeouts: { [number]: thread } = {}

Players.PlayerAdded:Connect(function(player: Player)
	local stringID = tostring(player.UserId)
	
	-- If the player disconnected recently
	if gatesFolder:FindFirstChild(stringID) then
		if destroyAllGatesTimeouts[player.UserId] ~= nil then
			task.cancel(destroyAllGatesTimeouts[player.UserId])
			destroyAllGatesTimeouts[player.UserId] = nil
		end
	else
		local folder = Instance.new("Folder") do
			folder.Name = stringID
			folder.Parent = gatesFolder
		end
	end
	
	-- Register the player in the Permissions service
	Permissions.RegisterPlayer(player.UserId)
end)

Players.PlayerRemoving:Connect(function(player: Player, reason: Enum.PlayerExitReason)
	-- Start a timer to destroy all their gates
	destroyAllGatesTimeouts[player.UserId] = task.delay(TIME_TO_DESTROY_GATES_AFTER_LEAVING, function()
		local playerFolder = gatesFolder:FindFirstChild(tostring(player.UserId))
		if playerFolder then
			-- TODO: Implement gate destruction
			warn("Leave timer has ran out for player " .. player.UserId .. ", but I have not implemented all gate destruction!")
		end
		
		destroyAllGatesTimeouts[player.UserId] = nil
	end)
	
	Permissions.UnregisterPlayer(player.UserId)
end)

-- ----------------------------- ------------ CLIENT REQUESTS ------------ -----------------------------

-- Permission request
Interactions.CreateQuery("Permission", { "GateID", "Action" }, function(player: Player, gate, action: Permissions.ActionType)
	if not Permissions.CanPlayerDo(player.UserId, gate.OwnerID, action, gate.Specification.Name) then
		return false, "Lacks permissions to do this!"
	end
	
	return true		
end)

-- Gate spawner
Interactions.CreateEvent("Spawn", { "GateID", "CFrame" }, function(player: Player, gate, cframe: CFrame)
	if not Permissions.CanPlayerDo(player.UserId, gate.OwnerID, "Spawn", gate.Specification.Name) then
		return false, "Lacks permissions to spawn a gate of this type"
	end		
	
	GateService.Instantiate(player.UserId, gate.Specification.Name, cframe, gate.Visuals, gate.Attributes)
	return true
end)

-- Gate destroyer
Interactions.CreateEvent("Destroy", { "GateID" }, function(player: Player, gate)
	if not Permissions.CanPlayerDo(player.UserId, gate.OwnerID, "Delete") then
		return false, "Lacks permissions to destroy this gate"
	end
	
	GateService.Destroy(gate.ID)
	return true
end)

-- Gate mover
Interactions.CreateEvent("Move", { "GateID", "CFrame" }, function(player: Player, gate, cframe: CFrame)
	if not Permissions.CanPlayerDo(player.UserId, gate.OwnerID, "Move") then
		return false, "Lacks permissions to move this gate"
	end		
	
	GateService.Move(gate.ID, cframe)
	return true
end)

-- Gate connector
Interactions.CreateEvent("Connect", { "GateID", "GateID", "string", "string" }, function(player: Player, fromGate, toGate, fromNode: string, toNode: string)
	if not Permissions.CanPlayerDo(player.UserId, fromGate.OwnerID, "Wire") then
		return false, "Lacks permissions to wire from this gate"
	end
	
	if not Permissions.CanPlayerDo(player.UserId, toGate.OwnerID, "Wire") then
		return false, "Lacks permissions to wire to this gate"
	end
	
	return GateService.Connect(fromGate.ID, toGate.ID, fromNode, toNode)
end)

-- Gate disconnect events
Interactions.CreateEvent("DisconnectSingle", { "GateID", "GateID", "string", "string" }, function(player: Player, fromGate, toGate, fromNode: string, toNode: string)
	if not Permissions.CanPlayerDo(player.UserId, fromGate.OwnerID, "Wire") then
		return false, "Lacks permissions to cut wires from this gate"
	end
	
	if not Permissions.CanPlayerDo(player.UserId, toGate.OwnerID, "Wire") then
		return false, "Lacks permissions to cut wires to this gate"
	end
	
	return GateService.Disconnect(fromGate.ID, toGate.ID, fromNode, toNode)
end)

Interactions.CreateEvent("DisconnectAllOutgoing", { "GateID" }, function(player: Player, fromGate)
	if not Permissions.CanPlayerDo(player.UserId, fromGate.OwnerID, "Wire") then
		return false, "Lacks permissions to cut wires from this gate"
	end
	
	-- Remember: Gate.Specification.Nodes: { "Inputs": { string }, "Outputs": { string } }
	for _, output in ipairs(fromGate.Specification.Nodes.Outputs) do
		local outgoing = Connections.GetAllOutgoing(fromGate.ID, output)
		for toGateID, connections in pairs(outgoing) do
			if not Permissions.CanPlayerDo(player.UserId, GatesHandler.Get(toGateID).OwnerID, "Wire") then
				print("Lacks permissions to cut wires to this gate")
				continue
			end
			
			for toNode, wire in pairs(connections) do
				local success, message = GateService.Disconnect(fromGate.ID, toGateID, output, toNode)
				if not success then
					return success, message
				end
			end
		end
	end
	
	return true
end)

-- Needle events
Interactions.CreateQuery("GetAttributeData", { "GateID" }, function(player: Player, gate)
	if not Permissions.CanPlayerDo(player.UserId, gate.OwnerID, "Configure") then
		return false, "Lacks permissions to change this gate's attributes!"
	end
	
	local returnData = {}
	local attributeData = gate.Specification.AttributeData
	for name, data in pairs(attributeData) do
		returnData[name] = {
			Value = gate.Attributes[name],
			AllowedValues = if typeof(attributeData[name].Default) == "boolean"
				then { true, false }
				else attributeData[name].AllowedValues
		}
	end
	
	return true, returnData
end)
