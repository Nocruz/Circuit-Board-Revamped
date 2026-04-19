--!strict
--[[ CLIENT REQUEST HANDLER
		This is the only script that communicates with clients.
		It does all validations, and then delegates to GateService.
		
		NEW API uses GateService directly instead of GateRegistry/Actions pattern.
]]

-- Requires and Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Safezones = require(ServerScriptService.Players.Safezones)
local PermissionService = require(ServerScriptService.Players.PermissionService)
local ClipboardService = require(ServerScriptService.Players.ClipboardService)
local GateService = require(ServerScriptService.GateService)
local GridService = require(ReplicatedStorage.Services.GridService)

local clientFolder = ReplicatedStorage:WaitForChild("Client")
local queriesFolder = clientFolder:WaitForChild("Queries")
local eventsFolder = clientFolder:WaitForChild("Events")

local gates = workspace:WaitForChild("Gates")

-- Cooldown state
local PlayerCooldowns: { [number]: true } = {}
local ACTION_COOLDOWN = 0.05 -- seconds

local function isAdmin(player: Player)
	return player.UserId == 159768840
end

local function ensureRemoteFunction(parent: Instance, name: string): RemoteFunction
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = parent
	return remote
end

-- ----------------------------- ------------ HELPER METHODS ----------- -----------------------------

local function isCooldowned(player: Player): boolean
	if isAdmin(player) then return false end
	return PlayerCooldowns[player.UserId] ~= nil
end

local function setCooldown(player: Player)
	if isCooldowned(player) then return end
	PlayerCooldowns[player.UserId] = true
	task.delay(ACTION_COOLDOWN, function()
		PlayerCooldowns[player.UserId] = nil
	end)
end

-- ----------------------------- ------------- QUERY ACTION ------------ -----------------------------

local query = ReplicatedStorage.Client.Queries:FindFirstChild("Query")
query.OnServerInvoke = function(player: Player, id: number, action: string): (boolean, string?)
	if isCooldowned(player) then 
		print(player.Name .. " tried querying an action, but is still in cooldown")
		return false, "Too fast!"
	end
	
	setCooldown(player)
	print(player.Name .. " is querying permissions of a gate")
	
	-- Failsafe against nil parameters
	if not id or not action then
		warn("Failure! Nil parameters found")
		return false, "Invalid parameters! Check with a mod"
	end
	-- Validate types
	if type(id) ~= "number" or type(action) ~= "string" then
		warn("Failure! Parameters are of wrong type")
		return false, "Invalid parameters! Check with a mod"
	end
	
	local gate = GateService.GetGateInstance(id)
	if not gate then
		warn("Failure! 'id' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end

	-- Validate action
	if not PermissionService.isValidAction(action) then
		warn("Failure! 'action' parameter is not a valid action")
		return false, "Invalid action! Check with a mod"
	end
	if not PermissionService.canPlayerDo(player.UserId, gate.OwnerId, action :: PermissionService.ActionType, gate.Name) then
		print("Failure! Player " .. player.Name .. " is not allowed to " .. action .. " this gate")
		return false, "Lacks permissions to " .. action .. " this gate"
	end
	
	return true, nil
end

-- ----------------------------- ----------- CHANGE PERMISSION --------- -----------------------------

local changePermission = ReplicatedStorage.Client.Events:FindFirstChild("ChangePermission")
changePermission.OnServerInvoke = function(player: Player, other: number, action: string, state: boolean): (boolean, string?)
	if isCooldowned(player) then 
		print(player.Name .. " tried changing permissions, but is still in cooldown")
		return false, "Too fast!"
	end

	setCooldown(player)
	print(player.Name .. " is changing permissions")

	-- Failsafe against nil parameters
	if other == nil or not action or state == nil then
		warn("Failure! Nil parameters found")
		return false, "Invalid parameters! Check with a mod"
	end
	-- Validate types
	if type(other) ~= "number" or type(action) ~= "string" or type(state) ~= "boolean" then
		warn("Failure! Parameters are of wrong type")
		return false, "Invalid parameters! Check with a mod"
	end

	-- Validate action
	if not PermissionService.isValidAction(action) then
		warn("Failure! 'action' parameter is not a valid action")
		return false, "Invalid action! Check with a mod"
	end
	local actionType = action :: PermissionService.ActionType
	
	-- Validate other
	if player.UserId == other then
		print("Failure! Player tried to change permissions of themselves")
		return false, "Can't change your own permissions!"
	end
	
	if state == true then 
		PermissionService.grantPermission(player.UserId, other, actionType)
	else 
		PermissionService.revokePermission(player.UserId, other, actionType)
	end
	
	return true, nil
end

-- ----------------------------- -------------- INTERACT EVENT ------------ -----------------------------

local interactFunction = ReplicatedStorage.Client.Events:FindFirstChild("Interact")
interactFunction.OnServerInvoke = function(player: Player, id: number): (boolean, string?)
	if isCooldowned(player) then 
		return false, "Too fast!"
	end
	setCooldown(player)
	
	if type(id) ~= "number" then return false, "Invalid parameters" end
	
	local gate = GateService.GetGateInstance(id)
	if not gate then return false, "Invalid gate" end
	
	if not PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Interact") then
		return false, "Lacks permissions to interact with this gate"
	end
	
	GateService.Interact(id, player)
	return true, nil
end

-- ----------------------------- -------------- SPAWN EVENT ------------ -----------------------------

local spawnFunction = ReplicatedStorage.Client.Events:FindFirstChild("Spawn")
spawnFunction.OnServerInvoke = function(player: Player, id: number, cframe: CFrame): (boolean, string?)
	if isCooldowned(player) then 
		print(player.Name .. " tried spawning a gate, but is still in cooldown")
		return false, "Too fast!"
	end
	
	setCooldown(player)
	print(player.Name .. " is requesting to spawn a gate...")
	
	-- Failsafe against nil parameters
	if not id or not cframe then
		warn("Failure! Nil parameters found")
		return false, "Invalid parameters! Check with a mod"
	end
	
	-- Validate types
	if type(id) ~= "number" then
		warn("Failure! 'id' parameter is not a number")
		return false, "Invalid parameters! Check with a mod"
	end
	if typeof(cframe) ~= "CFrame" then
		warn("Failure! 'cframe' parameter is not a CFrame")
		return false, "Invalid parameters! Check with a mod"
	else
		-- Validate CFrame
		if cframe.Position.X ~= cframe.Position.X or cframe.Position.Y ~= cframe.Position.Y or cframe.Position.Z ~= cframe.Position.Z then warn("Failure! 'cframe' parameter has NaN values"); return false, "Invalid position" end
		if not Safezones.IsValidPlacement(GridService.fromCFrame(cframe)._cframe) then
			warn("Failure! 'cframe' did not pass validity")
			return false, "Invalid placement"
		end
	end
	
	local gate = GateService.GetGateInstance(id)
	if not gate then
		warn("Failure! 'id' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end
	
	-- Validate permission for this spawn
	if not PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Spawn", gate.Name) then
		print("Failure! Player " .. player.Name .. " is not allowed to spawn this gate")
		return false, "Lacks permissions to spawn this gate"
	end
	
	-- Spawn the new gate via GateService
	local newGateId = GateService.Instantiate(player.UserId, gate.Name, cframe, gate.Visuals, gate.Attributes)
	print("Gate spawned with ID " .. newGateId)
	
	return true, nil
end

-- ----------------------------- --------------- MOVE EVENT ------------ -----------------------------

local moveFunction = ReplicatedStorage.Client.Events:FindFirstChild("Move")
moveFunction.OnServerInvoke = function(player: Player, id: number, cframe: CFrame): (boolean, string?)
	if isCooldowned(player) then 
		print(player.Name .. " tried moving a gate, but is still in cooldown")
		return false, "Too fast!"
	end

	setCooldown(player)
	print(player.Name .. " is requesting to move a gate...")

	-- Failsafe against nil parameters
	if not id or not cframe then
		warn("Failure! Nil parameters found")
		return false, "Invalid parameters! Check with a mod"
	end

	-- Validate types
	if type(id) ~= "number" then
		warn("Failure! 'id' parameter is not a number")
		return false, "Invalid parameters! Check with a mod"
	end
	if typeof(cframe) ~= "CFrame" then
		warn("Failure! 'cframe' parameter is not a CFrame")
		return false, "Invalid parameters! Check with a mod"
	else
		-- Validate CFrame
		if cframe.Position.X ~= cframe.Position.X or cframe.Position.Y ~= cframe.Position.Y or cframe.Position.Z ~= cframe.Position.Z then warn("Failure! 'cframe' parameter has NaN values"); return false, "Invalid position" end
		if not Safezones.IsValidPlacement(GridService.fromCFrame(cframe)._cframe) then
			warn("Failure! 'cframe' did not pass validity")
			return false, "Invalid placement"
		end
	end

	local gate = GateService.GetGateInstance(id)
	if not gate then
		warn("Failure! 'id' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end

	-- Validate permission for this move
	if not PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Move") then
		print("Failure! Player " .. player.Name .. " is not allowed to move this gate")
		return false, "Lacks permissions to move this gate"
	end

	-- Move via GateService
	GateService.Move(id, cframe)
	print("Gate " .. id .. " moved")
	
	return true, nil
end

-- ----------------------------- ------------- DESTROY EVENT ------------- -----------------------------

local destroyFunction = ReplicatedStorage.Client.Events:FindFirstChild("Destroy")
destroyFunction.OnServerInvoke = function(player: Player, id: number): (boolean, string?)
	if isCooldowned(player) then 
		print(player.Name .. " tried destroying a gate, but is still in cooldown")
		return false, "Too fast!"
	end

	setCooldown(player)
	print(player.Name .. " is requesting to destroy a gate...")

	-- Failsafe against nil parameters
	if not id then
		warn("Failure! Nil parameters found")
		return false, "Invalid parameters! Check with a mod"
	end

	-- Validate types
	if type(id) ~= "number" then
		warn("Failure! 'id' parameter is not a number")
		return false, "Invalid parameters! Check with a mod"
	end	

	local gate = GateService.GetGateInstance(id)
	if not gate then
		warn("Failure! 'id' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end

	-- Validate permission for this destroy
	if not PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Delete") then
		print("Failure! Player " .. player.Name .. " is not allowed to destroy this gate")
		return false, "Lacks permissions to destroy this gate"
	end

	GateService.Destroy(id)
	print("Gate " .. id .. " destroyed")
	
	return true, nil
end

local destroyAllFunction = ReplicatedStorage.Client.Events:FindFirstChild("DestroyAll")
destroyAllFunction.OnServerInvoke = function(player: Player): (boolean, string?)
	if isCooldowned(player) then 
		print(player.Name .. " tried destroying all its gates, but is still in cooldown")
		return false, "Too fast!"
	end

	setCooldown(player)
	print(player.Name .. " is requesting to destroy all its gates...")

	local folder = gates:FindFirstChild(tostring(player.UserId))
	if not folder then
		print(player.Name .. " has no Gates folder")
		return false, "Player had no Gates folder"
	end

	for _, gate in ipairs(folder:GetChildren()) do
		if gate:GetAttribute("GateId") then
			GateService.Destroy(gate:GetAttribute("GateId"))
		end
	end
	
	print("Player " .. player.UserId .. " destroyed all its gates!")
	
	return true, nil
end

-- ----------------------------- -------------- WIRE EVENTS ------------- --------------------

local wireFunction = ReplicatedStorage.Client.Events:FindFirstChild("Wire")
wireFunction.OnServerInvoke = function(player: Player, fromid: number, toid: number, fromNode: string, toNode: string): (boolean, string?)
	if isCooldowned(player) then 
		print(player.Name .. " tried wiring a gate, but is still in cooldown")
		return false, "Too fast!"
	end

	setCooldown(player)
	print(player.Name .. " is requesting to wire a gate...")

	-- Failsafe against nil parameters
	if not fromid or not toid or not fromNode or not toNode then
		warn("Failure! Nil parameters found")
		return false, "Invalid parameters! Check with a mod"
	end

	-- Validate types
	if type(fromid) ~= "number" or type(toid) ~= "number" then
		warn("Failure! Gate IDs are not numbers")
		return false, "Invalid parameters! Check with a mod"
	end
	if type(fromNode) ~= "string" or type(toNode) ~= "string" then
		warn("Failure! Node names are not strings")
		return false, "Invalid parameters! Check with a mod"
	end

	local fromGate = GateService.GetGateInstance(fromid)
	local toGate = GateService.GetGateInstance(toid)
	if not fromGate then
		warn("Failure! 'fromid' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end
	if not toGate then
		warn("Failure! 'toid' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end

	-- Validate permissions
	if not PermissionService.canPlayerDo(player.UserId, fromGate.OwnerId, "Wire") or not PermissionService.canPlayerDo(player.UserId, toGate.OwnerId, "Wire") then
		print("Failure! Player " .. player.Name .. " is not allowed to wire this gate")
		return false, "Lacks permissions to wire this gate"
	end
	
	-- Validate nodes exist
	if not fromGate.Nodes.Outputs[fromNode] then
		warn("Failure! FromGate has no output '" .. fromNode .. "'")
		return false, "Invalid output node"
	end
	if not toGate.Nodes.Inputs[toNode] then
		warn("Failure! ToGate has no input '" .. toNode .. "'")
		return false, "Invalid input node"
	end
	
	-- Check if connection already exists
	local outputNode = fromGate.Nodes.Outputs[fromNode]
	local inputNode = toGate.Nodes.Inputs[toNode]
	
	if outputNode[toid] and outputNode[toid][toNode] then
		print("Failure! Already connected")
		return false, "Already connected"
	end
	
	-- Connect via GateService
	GateService.Connect(fromid, toid, { from = fromNode, to = toNode })
	print("Connected gate " .. fromid .. " output " .. fromNode .. " to gate " .. toid .. " input " .. toNode)
	
	return true, nil
end

local cutAllFunction = ReplicatedStorage.Client.Events:FindFirstChild("CutAll")
cutAllFunction.OnServerInvoke = function(player: Player, id: number): (boolean, string?)
	if isCooldowned(player) then 
		print(player.Name .. " tried disconnecting a gate, but is still in cooldown")
		return false, "Too fast!"
	end

	setCooldown(player)
	print(player.Name .. " is requesting to disconnect a gate...")

	-- Failsafe against nil parameters
	if not id then
		warn("Failure! Nil parameters found")
		return false, "Invalid parameters! Check with a mod"
	end

	-- Validate types
	if type(id) ~= "number" then
		warn("Failure! 'id' parameter is not a number")
		return false, "Invalid parameters! Check with a mod"
	end	

	local gate = GateService.GetGateInstance(id)
	if not gate then
		warn("Failure! 'id' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end

	-- Validate permission
	if not PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Wire") then
		print("Failure! Player " .. player.Name .. " is not allowed to disconnect this gate")
		return false, "Lacks permissions to disconnect this gate"
	end

	-- Disconnect all outputs
	for outputName, nodeInstance in pairs(gate.Nodes.Outputs) do
		for downstreamGateID in pairs(nodeInstance) do
			for inputNodeName in pairs(nodeInstance[downstreamGateID]) do
				GateService.Disconnect(id, downstreamGateID, { from = outputName, to = inputNodeName })
			end
		end
	end
	
	print("Gate " .. id .. " all outputs disconnected")
	return true, nil
end

local cutFunction = ReplicatedStorage.Client.Events:FindFirstChild("Cut")
cutFunction.OnServerInvoke = function(player: Player, fromid: number, toid: number, fromNode: string, toNode: string): (boolean, string?)
	if isCooldowned(player) then 
		print(player.Name .. " tried cutting a wire, but is still in cooldown")
		return false, "Too fast!"
	end

	setCooldown(player)
	print(player.Name .. " is requesting to cut a wire...")

	-- Failsafe against nil parameters
	if not fromid or not toid or not fromNode or not toNode then
		warn("Failure! Nil parameters found")
		return false, "Invalid parameters! Check with a mod"
	end

	-- Validate types
	if type(fromid) ~= "number" or type(toid) ~= "number" then
		warn("Failure! Gate IDs are not numbers")
		return false, "Invalid parameters! Check with a mod"
	end
	if type(fromNode) ~= "string" or type(toNode) ~= "string" then
		warn("Failure! Node names are not strings")
		return false, "Invalid parameters! Check with a mod"
	end

	local fromGate = GateService.GetGateInstance(fromid)
	local toGate = GateService.GetGateInstance(toid)
	if not fromGate then
		warn("Failure! 'fromid' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end
	if not toGate then
		warn("Failure! 'toid' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end

	-- Validate permissions
	if not PermissionService.canPlayerDo(player.UserId, fromGate.OwnerId, "Wire") or not PermissionService.canPlayerDo(player.UserId, toGate.OwnerId, "Wire") then
		print("Failure! Player " .. player.Name .. " is not allowed to cut this wire")
		return false, "Lacks permissions to cut this wire"
	end

	-- Validate nodes exist
	if not fromGate.Nodes.Outputs[fromNode] then
		warn("Failure! FromGate has no output '" .. fromNode .. "'")
		return false, "Invalid output node"
	end
	if not toGate.Nodes.Inputs[toNode] then
		warn("Failure! ToGate has no input '" .. toNode .. "'")
		return false, "Invalid input node"
	end

	-- Check if connection exists
	local outputNode = fromGate.Nodes.Outputs[fromNode]
	if not (outputNode[toid] and outputNode[toid][toNode]) then
		print("Failure! Connection doesn't exist")
		return false, "Invalid wire"
	end
	
	-- Disconnect via GateService
	GateService.Disconnect(fromid, toid, { from = fromNode, to = toNode })
	print("Disconnected gate " .. fromid .. " output " .. fromNode .. " from gate " .. toid .. " input " .. toNode)
	
	return true, nil
end

-- ----------------------------- -------------- CONFIGURE EVENTS ------------- -----------------------------

local configurationQuery = ReplicatedStorage.Client.Queries:FindFirstChild("GateConfiguration")
configurationQuery.OnServerInvoke = function(player: Player, id: number): any
	if isCooldowned(player) then 
		print(player.Name .. " tried querying a gate's config, but is still in cooldown")
		return false, "Too fast!"
	end

	setCooldown(player)
	print(player.Name .. " is requesting to query a gate's config...")

	-- Failsafe against nil parameters
	if not id then
		warn("Failure! Nil parameters found")
		return false, "Invalid parameters! Check with a mod"
	end

	-- Validate types
	if type(id) ~= "number" then
		warn("Failure! 'id' parameter is not a number")
		return false, "Invalid parameters! Check with a mod"
	end

	local gate = GateService.GetGateInstance(id)
	if not gate then
		warn("Failure! 'id' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end

	-- Validate permission
	if not PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Configure") then
		print("Failure! Player " .. player.Name .. " is not allowed to configure this gate")
		return false, "Lacks permissions to configure this gate"
	end
	
	return true, { Data = gate.AttributeData, Current = gate.Attributes }
end

local configureFunction = ReplicatedStorage.Client.Events:FindFirstChild("Configure")
configureFunction.OnServerInvoke = function(player: Player, id: number, attribute: string, value: any): (boolean, string?)
	-- if isCooldowned(player) then 
	-- 	print(player.Name .. " tried configuring a gate, but is still in cooldown")
	-- 	return false, "Too fast!"
	-- end

	setCooldown(player)
	print(player.Name .. " is requesting to configure a gate...")

	-- Failsafe against nil parameters
	if not id or not attribute then
		warn("Failure! Nil parameters found")
		return false, "Invalid parameters! Check with a mod"
	end

	-- Validate types
	if type(id) ~= "number" then
		warn("Failure! 'id' parameter is not a number")
		return false, "Invalid parameters! Check with a mod"
	end
	if type(attribute) ~= "string" then
		warn("Failure! 'attribute' parameter is not a string")
		return false, "Invalid parameters! Check with a mod"
	end

	local gate = GateService.GetGateInstance(id)
	if not gate then
		warn("Failure! 'id' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end

	-- Validate permission
	if not PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Configure") then
		print("Failure! Player " .. player.Name .. " is not allowed to configure this gate")
		return false, "Lacks permissions to configure this gate"
	end
	
	-- Set attribute via Ge
	GateService.TrySetAttribute(id, attribute, value)
	print("Gate " .. id .. " attribute " .. attribute .. " set to " .. tostring(value))

	return true, nil
end

-- ----------------------------- -------------- CLIPBOARD ----------- -----------------------------

local clipboardListQuery = ensureRemoteFunction(queriesFolder, "ClipboardList")
clipboardListQuery.OnServerInvoke = function(player: Player): (boolean, string?, any?)
	if isCooldowned(player) then
		return false, "Too fast!", nil
	end

	setCooldown(player)
	return ClipboardService.ListSaves(player.UserId)
end

local clipboardPreviewQuery = ensureRemoteFunction(queriesFolder, "ClipboardPreview")
clipboardPreviewQuery.OnServerInvoke = function(player: Player, saveName: string): (boolean, string?, any?)
	if isCooldowned(player) then
		return false, "Too fast!", nil
	end

	if type(saveName) ~= "string" then
		return false, "Invalid save name.", nil
	end

	setCooldown(player)
	return ClipboardService.GetSavePreview(player.UserId, saveName)
end

local clipboardSaveFunction = ensureRemoteFunction(eventsFolder, "ClipboardSave")
clipboardSaveFunction.OnServerInvoke = function(player: Player, saveName: string, gateIds: { number }): (boolean, string?, any?)
	if isCooldowned(player) then
		return false, "Too fast!", nil
	end

	if type(saveName) ~= "string" or type(gateIds) ~= "table" then
		return false, "Invalid clipboard save.", nil
	end

	setCooldown(player)
	return ClipboardService.SaveSelection(player, saveName, gateIds)
end

local clipboardLoadFunction = ensureRemoteFunction(eventsFolder, "ClipboardLoad")
clipboardLoadFunction.OnServerInvoke = function(player: Player, saveName: string, anchorCFrame: CFrame): (boolean, string?)
	if isCooldowned(player) then
		return false, "Too fast!"
	end

	if type(saveName) ~= "string" or typeof(anchorCFrame) ~= "CFrame" then
		return false, "Invalid clipboard load."
	end

	setCooldown(player)
	return ClipboardService.LoadSave(player, saveName, anchorCFrame)
end

local clipboardDeleteFunction = ensureRemoteFunction(eventsFolder, "ClipboardDelete")
clipboardDeleteFunction.OnServerInvoke = function(player: Player, saveName: string): (boolean, string?, any?)
	if isCooldowned(player) then
		return false, "Too fast!", nil
	end

	if type(saveName) ~= "string" then
		return false, "Invalid save name.", nil
	end

	setCooldown(player)
	return ClipboardService.DeleteSave(player, saveName)
end
