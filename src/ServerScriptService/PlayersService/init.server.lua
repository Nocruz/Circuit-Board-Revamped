--[[ PLAYERS SERVICE
		Exposes events to cross the Server-Client boundary.
		Handles Permissions, Cooldowns, Filtering and Input sanitization.    
]]

-- Requires and Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Permissions = require(script.Permissions)
local Interactions = require(script.Interactions)
local Saves = require(script.Saves)

local GateService = require(ServerScriptService.GateService)
local Connections = require(ServerScriptService.GateService.Connections)
local Attributes  = require(ServerScriptService.GateService.Attributes)
local Updates = require(ServerScriptService.GateService.Updates)
local GatesHandler = require(ServerScriptService.GateService.Handlers.GatesHandler)

local EffectsService = require(ReplicatedStorage.EffectsService)

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
			for _, gate in ipairs(playerFolder:GetChildren()) do
				local gateID = gate:GetAttribute("GateID")
				if not gateID then warn("Player " .. player.UserId .. " had an unknown object inside their Gates folder!"); continue end;
				GateService.Destroy(gateID)
			end
			warn("Leave timer has ran out for player " .. player.UserId .. ", and its gates were probably destroyed, but its not certain. Remove this once confirmed it works!")
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
	
	EffectsService.PlaySFX("Place Gate", cframe.Position)
	
	GateService.Instantiate(player.UserId, gate.Specification.Name, cframe, gate.Visuals, gate.Attributes)
	return true
end)

-- Gate destroyer
Interactions.CreateEvent("Destroy", { "GateIDTable" }, function(player: Player, gates)
	local skipped = false
	local allowedGates = {}
	
	for _, gate in ipairs(gates) do
		if not Permissions.CanPlayerDo(player.UserId, gate.OwnerID, "Delete") then
			skipped = true
			continue
		end
		table.insert(allowedGates, gate.ID)
	end
	
	local soundAnchorGate = if #allowedGates > 0 then GatesHandler.Get(allowedGates[1]) else nil
	for i, gateID in ipairs(allowedGates) do
		GateService.Destroy(gateID)
	end
	
	if soundAnchorGate then EffectsService.PlaySFX("Destroy Gate", soundAnchorGate.Model:GetPivot().Position) end
	
	return true, if skipped then "Some gates were skipped because of permissions protection" else nil
end)

-- Gate mover
Interactions.CreateEvent("Move", { "GateID", "CFrame" }, function(player: Player, gate, cframe: CFrame)
	if not Permissions.CanPlayerDo(player.UserId, gate.OwnerID, "Move") then
		return false, "Lacks permissions to move this gate"
	end
	
	EffectsService.PlaySFX("Place Gate", cframe.Position)
	
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
	
	EffectsService.PlaySFX("Connect Wire", fromGate.Model:GetPivot().Position)
	
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
	
	EffectsService.PlaySFX("Cut Wire", fromGate.Model:GetPivot().Position)
	
	return GateService.Disconnect(fromGate.ID, toGate.ID, fromNode, toNode)
end)

Interactions.CreateEvent("DisconnectAllOutgoing", { "GateID" }, function(player: Player, fromGate)
	if not Permissions.CanPlayerDo(player.UserId, fromGate.OwnerID, "Wire") then
		return false, "Lacks permissions to cut wires from this gate"
	end
	
	local hasCut = false
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
				else
					hasCut = true
				end
			end
		end
	end
	
	if hasCut then EffectsService.PlaySFX("Cut Wire", fromGate.Model:GetPivot().Position) end
	
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

Interactions.CreateEvent("SetAttributes", { "GateID", "AttributesTable" }, function(player: Player, gate, attributeTable)
	if not Permissions.CanPlayerDo(player.UserId, gate.OwnerID, "Configure") then
		return false, "Lacks permissions to change this gate's attributes!"
	end
	
	for name, value in pairs(attributeTable) do
		local valid, attribute = Attributes.IsValid(value, gate.Specification.AttributeData[name])
		if not valid then
			return false, "Attribute " .. name .. " did not have a valid value! Try again"
		end
		gate.Attributes[name] = attribute
	end
	
	Updates.Propagate(gate.ID)
	return true
end)

-- Clipboard events
Interactions.CreateQuery("GetSavesData", { }, function(player: Player)
	local data = Saves.GetAll(player.UserId)
	
	if data then
		return true, data
	else
		return false, "Error while obtaining the data!"
	end
end)

Interactions.CreateEvent("Save", { "SaveIdentifier", "GateIDTable" }, function(player: Player, identifier: string, gates: { number })
	local infoMessage = ""
	
	local allowedGates = {}
	for _, gate in ipairs(gates) do
		if not Permissions.CanPlayerDo(player.UserId, gate.OwnerID, "Move") then
			infoMessage = "Lacks permissions to move a gate, so its skipped!"
			continue
		end
		if not Permissions.CanPlayerDo(player.UserId, gate.OwnerID, "Spawn", gate.Specification.Name) then
			infoMessage = "Lacks permissions to spawn a gate, so its skipped!"
			continue
		end
		table.insert(allowedGates, gate.ID)
	end
	
	if #allowedGates < 1 then
		return false, "At least select 1 valid gate to save. Check permissions"
	end
	
	local success, message, result = Saves.Save(player.UserId, identifier, allowedGates)
	if not success then
		return false, message
	end
	
	return true, infoMessage, result
end)

Interactions.CreateLoadEvent("Load", { "SaveIdentifier", "CFrame" }, function(player: Player, identifier: string, loadCFrame: CFrame)
	return Saves.Load(player.UserId, identifier, loadCFrame)
end)

Interactions.CreateEvent("EraseSave", { "SaveIdentifier" }, function(player: Player, identifier: string)
	return Saves.Erase(player.UserId, identifier)
end)
