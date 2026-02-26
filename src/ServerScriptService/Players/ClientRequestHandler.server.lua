--!strict
--[[ CLIENT REQUEST HANDLER
		This is the only script that communicates with clients.
		It does all validations, and then delegates to the other GateManagers.
		
		On times before this script, all GateManagers used to be Scripts.
		This one allows them to become ModuleScripts and blossom with their true intents.
]]

-- Requires and Services
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PermissionService = require(ServerScriptService.Players.PermissionService)
local GateRegistry = require(ServerScriptService.Gates.Definitions.GateRegistry)
local WireService = require(ServerScriptService.Gates.Services.WireService)
local GateVisualsService = require(ReplicatedStorage.Services.GateVisualsService)
local GridService = require(ReplicatedStorage.Services.GridService)

-- Gate Actions
local Spawner = require(ServerScriptService.Gates.Actions.Spawner)
local Mover = require(ServerScriptService.Gates.Actions.Mover)
local Wirer = require(ServerScriptService.Gates.Actions.Wirer)
local Configurer = require(ServerScriptService.Gates.Actions.Configurer)

-- Debugging
local Logger = require(ReplicatedStorage.Services.LoggerService)
local log = Logger.new("ClientRequestHandler")

-- Cooldown state
local PlayerCooldowns: { [number]: true } = {}
local ACTION_COOLDOWN = 0.05 -- seconds

-- ----------------------------- ------------ HELPER METHODS ----------- -----------------------------

local function isCooldowned(player: Player): boolean
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
		log.info(player.Name .. " tried querying an action, but is still in cooldown")
		return false, "Too fast!"
	end
	
	setCooldown(player)
	log.info(player.Name .. " is querying permissions of a gate")
	
	-- Failsafe against nil parameters
	if not id or not action then
		log.warn("Failure! Nil parameters found")
		return false, "Invalid parameters! Check with a mod"
	end
	-- Validate types
	if type(id) ~= "number" or type(action) ~= "string" then
		log.warn("Failure! Parameters are of wrong type")
		return false, "Invalid parameters! Check with a mod"
	end
	
	local gate = GateRegistry:tryGetGateFromId(id)
	if not gate then
		log.warn("Failure! 'id' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end

	-- Validate action
	if not PermissionService.isValidAction(action) then
		log.warn("Failure! 'action' parameter is not a valid action")
		return false, "Invalid action! Check with a mod"
	end
	if not PermissionService.canPlayerDo(player.UserId, gate.OwnerId, action :: PermissionService.ActionType, gate.Class.name) then
		log.info("Failure! Player " .. player.Name .. " is not allowed to " .. action .. " this gate")
		return false, "Lacks permissions to " .. action .. " this gate"
	end
	
	return true, nil
end

-- ----------------------------- ----------- CHANGE PERMISSION --------- -----------------------------

local changePermission = ReplicatedStorage.Client.Events:FindFirstChild("ChangePermission")
changePermission.OnServerInvoke = function(player: Player, other: number, action: string, state: boolean): (boolean, string?)
	if isCooldowned(player) then 
		log.info(player.Name .. " tried spawning a gate, but is still in cooldown")
		return false, "Too fast!"
	end

	setCooldown(player)
	log.info(player.Name .. " is querying permissions of a gate")

	-- Failsafe against nil parameters
	if other == nil or not action or state == nil then
		log.warn("Failure! Nil parameters found")
		return false, "Invalid parameters! Check with a mod"
	end
	-- Validate types
	if type(other) ~= "number" or type(action) ~= "string" or type(state) ~= "boolean" then
		log.warn("Failure! Parameters are of wrong type")
		return false, "Invalid parameters! Check with a mod"
	end

	-- Validate action
	if not PermissionService.isValidAction(action) then
		log.warn("Failure! 'action' parameter is not a valid action")
		return false, "Invalid action! Check with a mod"
	end
	local action = action :: PermissionService.ActionType
	
	-- Validate other
	if player.UserId == other then
		log.info("Failure! Player tried to change permissions of themselves")
		return false, "Can't change your own permissions!"
	end
	
	if state == true then PermissionService.grantPermission(player.UserId, other, action)
	else PermissionService.revokePermission(player.UserId, other, action) end
	
	return true, nil
end

-- ----------------------------- -------------- SPAWN EVENT ------------ -----------------------------

local spawnFunction = ReplicatedStorage.Client.Events:FindFirstChild("Spawn")
spawnFunction.OnServerInvoke = function(player: Player, id: number, cframe: CFrame, visuals: GateVisualsService.TGateVisuals): (boolean, string?)
	if isCooldowned(player) then 
		log.info(player.Name .. " tried spawning a gate, but is still in cooldown")
		return false, "Too fast!"
	end
	
	setCooldown(player)
	log.info(player.Name .. " is requesting to spawn a gate...")
	
	-- Failsafe against nil parameters
	if not id or not cframe or not visuals then
		log.warn("Failure! Nil parameters found")
		return false, "Invalid parameters! Check with a mod"
	end
	
	-- Validate types
	if type(id) ~= "number" then
		log.warn("Failure! 'id' parameter is not a number")
		return false, "Invalid parameters! Check with a mod"
	end
	if typeof(cframe) ~= "CFrame" then
		log.warn("Failure! 'cframe' parameter is not a CFrame")
		return false, "Invalid parameters! Check with a mod"
	else
		-- Validate CFrame
		local p = cframe.Position
		if p.Magnitude > 1000 then log.warn("Failure! 'cframe' parameter is too far from origin"); return false, "Too far from middle" end
		if p.Y < -5 then log.warn("Failure! 'cframe' parameter is too low"); return false, "Too low" end
		if p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z then log.warn("Failure! 'cframe' parameter has NaN values"); return false, "Invalid position" end
	end
	if not GateVisualsService.validateVisuals(visuals) then
		log.warn("Failure! 'visuals' is not a valid visual")
		return false, "Invalid visuals! Check with a mod"
	end
	
	local gate = GateRegistry:tryGetGateFromId(id)
	if not gate then
		log.warn("Failure! 'id' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end
	
	-- Validate permission for this spawn
	if not PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Spawn", gate.Class.name) then
		log.info("Failure! Player " .. player.Name .. " is not allowed to spawn this gate")
		return false, "Lacks permissions to spawn this gate"
	end
	
	if not gate.Model then
		log.warn("Failure! Gate has no model. Non-physical gates are not implemented yet")
		return false, "No gate model. Check with a mod"
	end
	
	local filteredDisplayName = TextService:FilterStringAsync(visuals.DisplayName, player.UserId):GetNonChatStringForBroadcastAsync()
	visuals.DisplayName = filteredDisplayName
	visuals.DisplayName = string.sub(visuals.DisplayName, 1, 32)
	
	Spawner.Spawn(gate.Class, visuals, GridService.fromCFrame(cframe)._cframe, player.UserId)
	return true, nil
end

-- ----------------------------- --------------- MOVE EVENT ------------ -----------------------------

local moveFunction = ReplicatedStorage.Client.Events:FindFirstChild("Move")
moveFunction.OnServerInvoke = function(player: Player, id: number, cframe: CFrame): (boolean, string?)
	if isCooldowned(player) then 
		log.info(player.Name .. " tried moving a gate, but is still in cooldown")
		return false, "Too fast!"
	end

	setCooldown(player)
	log.info(player.Name .. " is requesting to move a gate...")

	-- Failsafe against nil parameters
	if not id or not cframe then
		log.warn("Failure! Nil parameters found")
		return false, "Invalid parameters! Check with a mod"
	end

	-- Validate types
	if type(id) ~= "number" then
		log.warn("Failure! 'id' parameter is not a number")
		return false, "Invalid parameters! Check with a mod"
	end
	if typeof(cframe) ~= "CFrame" then
		log.warn("Failure! 'cframe' parameter is not a CFrame")
		return false, "Invalid parameters! Check with a mod"
	else
		-- Validate CFrame
		local p = cframe.Position
		if p.Magnitude > 1000 then log.warn("Failure! 'cframe' parameter is too far from origin"); return false, "Too far from middle" end
		if p.Y < -5 then log.warn("Failure! 'cframe' parameter is too low"); return false, "Too low" end
		if p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z then log.warn("Failure! 'cframe' parameter has NaN values"); return false, "Invalid position" end
	end

	local gate = GateRegistry:tryGetGateFromId(id)
	if not gate then
		log.warn("Failure! 'id' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end

	-- Validate permission for this spawn
	if not PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Move") then
		log.info("Failure! Player " .. player.Name .. " is not allowed to move this gate")
		return false, "Lacks permissions to move this gate"
	end

	if not gate.Model then
		log.warn("Failure! Gate has no model. Non-physical gates are not implemented yet")
		return false, "No gate model. Check with a mod"
	end
	
	Mover.Move(gate.Model, GridService.fromCFrame(cframe)._cframe)
	
	-- Update wire hitboxes
	if gate.Inputs then
		for node, gates in pairs(gate.Inputs) do
			for from, _ in pairs(gates) do
				if not from.Connections then 
					log.warn("Gate " .. from.Id .. " is not OutConnected to " .. gate.Id .. ", despite gate saying so")
					continue
				end
				local wire = from.Connections[gate][node].Wire
				if wire then WireService.UpdateWireHitbox(wire) end
			end
		end
	end
	
	if gate.Connections then
		for toGate, nodes in pairs(gate.Connections) do
			for node, data in pairs(nodes) do
				if data.Wire then WireService.UpdateWireHitbox(data.Wire) end
			end
		end
	end
	
	return true, nil
end

-- ----------------------------- ------------- DESTROY EVENT ------------- -----------------------------

local destroyFunction = ReplicatedStorage.Client.Events:FindFirstChild("Destroy")
destroyFunction.OnServerInvoke = function(player: Player, id: number): (boolean, string?)
	if isCooldowned(player) then 
		log.info(player.Name .. " tried destroying a gate, but is still in cooldown")
		return false, "Too fast!"
	end

	setCooldown(player)
	log.info(player.Name .. " is requesting to destroy a gate...")

	-- Failsafe against nil parameters
	if not id then
		log.warn("Failure! Nil parameters found")
		return false, "Invalid parameters! Check with a mod"
	end

	-- Validate types
	if type(id) ~= "number" then
		log.warn("Failure! 'id' parameter is not a number")
		return false, "Invalid parameters! Check with a mod"
	end	
	
	local gate = GateRegistry:tryGetGateFromId(id)
	if not gate then
		log.warn("Failure! 'id' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end

	-- Validate permission for this spawn
	if not PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Delete") then
		log.info("Failure! Player " .. player.Name .. " is not allowed to destroy this gate")
		return false, "Lacks permissions to destroy this gate"
	end
	
	-- Validate the model
	if not gate.Model then
		log.warn("Failure! Gate has no model. Non-physical gates are not implemented yet")
		return false, "No gate model. Check with a mod"
	end
	
	Wirer.CutAllOut(gate)
	Wirer.CutAllIn(gate)
	Spawner.Despawn(id)
	
	return true, nil
end

-- ----------------------------- -------------- WIRE EVENTS ------------- -----------------------------

local wireFunction = ReplicatedStorage.Client.Events:FindFirstChild("Wire")
wireFunction.OnServerInvoke = function(player: Player, fromid: number, toid: number, input: string): (boolean, string?)
	if isCooldowned(player) then 
		log.info(player.Name .. " tried wiring a gate, but is still in cooldown")
		return false, "Too fast!"
	end

	setCooldown(player)
	log.info(player.Name .. " is requesting to wire a gate...")

	-- Failsafe against nil parameters
	if not fromid or not toid or not input then
		log.warn("Failure! Nil parameters found")
		return false, "Invalid parameters! Check with a mod"
	end

	-- Validate types
	if type(fromid) ~= "number" then
		log.warn("Failure! 'fromid' parameter is not a number")
		return false, "Invalid parameters! Check with a mod"
	end
	if type(toid) ~= "number" then
		log.warn("Failure! 'toid' parameter is not a number")
		return false, "Invalid parameters! Check with a mod"
	end
	if type(input) ~= "string" then
		log.warn("Failure! 'input' parameter is not a string")
		return false, "Invalid parameters! Check with a mod"
	end

	local fromGate = GateRegistry:tryGetGateFromId(fromid)
	local toGate = GateRegistry:tryGetGateFromId(toid)
	if not fromGate then
		log.warn("Failure! 'fromid' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end
	if not toGate then
		log.warn("Failure! 'toid' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end

	-- Validate permission for this spawn
	if not PermissionService.canPlayerDo(player.UserId, fromGate.OwnerId, "Wire") or not PermissionService.canPlayerDo(player.UserId, toGate.OwnerId, "Wire") then
		log.info("Failure! Player " .. player.Name .. " is not allowed to wire this gate")
		return false, "Lacks permissions to wire this gate"
	end
	
	-- Validate nodes
	if not fromGate.Connections or fromGate.Output == nil then
		log.warn("Failure! FromGate has no outputs")
		return false, "FromGate has no outputs"
	end
	if not toGate.Inputs then
		log.warn("Failure! ToGate has no inputs")
		return false, "ToGate has no inputs"
	end
	
	local node = toGate.Inputs[input]
	if not node then
		log.warn("Failure! '" .. input .. "' is not a valid input for ToGate")
		return false, "Invalid input name!"
	end
	
	if node[fromGate] or (fromGate.Connections[toGate] and fromGate.Connections[toGate][input]) then
		log.info("Failure! '" .. fromGate.Id .. "' is already connected to " .. input)
		return false, "Already connected"
	end
	
	Wirer.Wire(fromGate, toGate, input)
	
	return true, nil
end

local disconnectFunction = ReplicatedStorage.Client.Events:FindFirstChild("CutAll")
disconnectFunction.OnServerInvoke = function(player: Player, id: number): (boolean, string?)
	if isCooldowned(player) then 
		log.info(player.Name .. " tried disconnecting a gate, but is still in cooldown")
		return false, "Too fast!"
	end

	setCooldown(player)
	log.info(player.Name .. " is requesting to disconnect a gate...")

	-- Failsafe against nil parameters
	if not id then
		log.warn("Failure! Nil parameters found")
		return false, "Invalid parameters! Check with a mod"
	end

	-- Validate types
	if type(id) ~= "number" then
		log.warn("Failure! 'id' parameter is not a number")
		return false, "Invalid parameters! Check with a mod"
	end	

	local gate = GateRegistry:tryGetGateFromId(id)
	if not gate then
		log.warn("Failure! 'id' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end

	-- Validate permission for this spawn
	if not PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Wire") then
		log.info("Failure! Player " .. player.Name .. " is not allowed to disconnect this gate")
		return false, "Lacks permissions to disconnect this gate"
	end

	-- Validate the model
	if not gate.Model then
		log.warn("Failure! Gate has no model. Non-physical gates are not implemented yet")
		return false, "No gate model. Check with a mod"
	end

	-- Validate nodes
	if not gate.Connections then
		log.warn("Failure! FromGate has no outputs")
		return false, "Invalid gate! Check with a mod"
	end

	Wirer.CutAllOut(gate)
	return true, nil
end

local cutFunction = ReplicatedStorage.Client.Events:FindFirstChild("Cut")
cutFunction.OnServerInvoke = function(player: Player, fromid: number, toid: number, input: string): (boolean, string?)
	if isCooldowned(player) then 
		log.info(player.Name .. " tried cutting a wire, but is still in cooldown")
		return false, "Too fast!"
	end

	setCooldown(player)
	log.info(player.Name .. " is requesting to cut a wire...")

	-- Failsafe against nil parameters
	if not fromid or not toid or not input then
		log.warn("Failure! Nil parameters found")
		return false, "Invalid parameters! Check with a mod"
	end

	-- Validate types
	if type(fromid) ~= "number" then
		log.warn("Failure! 'fromid' parameter is not a number")
		return false, "Invalid parameters! Check with a mod"
	end
	if type(toid) ~= "number" then
		log.warn("Failure! 'toid' parameter is not a number")
		return false, "Invalid parameters! Check with a mod"
	end
	if type(input) ~= "string" then
		log.warn("Failure! 'input' parameter is not a string")
		return false, "Invalid parameters! Check with a mod"
	end

	local fromGate = GateRegistry:tryGetGateFromId(fromid)
	local toGate = GateRegistry:tryGetGateFromId(toid)
	if not fromGate then
		log.warn("Failure! 'fromid' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end
	if not toGate then
		log.warn("Failure! 'toid' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end

	-- Validate permission for this spawn
	if not PermissionService.canPlayerDo(player.UserId, fromGate.OwnerId, "Wire") or not PermissionService.canPlayerDo(player.UserId, toGate.OwnerId, "Wire") then
		log.info("Failure! Player " .. player.Name .. " is not allowed to cut this wire")
		return false, "Lacks permissions to cut this wire"
	end

	-- Validate nodes
	if not fromGate.Connections then
		log.warn("Failure! FromGate has no outputs")
		return false, "Invalid gate! Check with a mod"
	end
	if not toGate.Inputs then
		log.warn("Failure! ToGate has no inputs")
		return false, "Invalid gate! Check with a mod"
	end

	local node = toGate.Inputs[input]
	if not node then
		log.warn("Failure! '" .. input .. "' is not a valid input for ToGate")
		return false, "Invalid input! Check with a mod"
	end

	if not node[fromGate] or not (fromGate.Connections[toGate] and fromGate.Connections[toGate][input]) then
		log.info("Failure! '" .. fromGate.Id .. "' is not connected to " .. input)
		return false, "Invalid wire! Check with a mod"
	end
	
	Wirer.Cut(fromGate, toGate, input)
	return true, nil
end

-- ----------------------------- -------------- NEEDLE EVENTS ------------- -----------------------------

local configurationQuery = ReplicatedStorage.Client.Queries:FindFirstChild("GateConfiguration")
configurationQuery.OnServerInvoke = function(player: Player, id: number): any
	if isCooldowned(player) then 
		log.info(player.Name .. " tried querying a gate's config, but is still in cooldown")
		return false, "Too fast!"
	end

	setCooldown(player)
	log.info(player.Name .. " is requesting to query a gate's config...")

	-- Failsafe against nil parameters
	if not id then
		log.warn("Failure! Nil parameters found")
		return false, "Invalid parameters! Check with a mod"
	end

	-- Validate types
	if type(id) ~= "number" then
		log.warn("Failure! 'id' parameter is not a number")
		return false, "Invalid parameters! Check with a mod"
	end

	local gate = GateRegistry:tryGetGateFromId(id)
	if not gate then
		log.warn("Failure! 'id' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end

	-- Validate permission for this spawn
	if not PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Configure") then
		log.info("Failure! Player " .. player.Name .. " is not allowed to configure this gate")
		return false, "Lacks permissions to configure this gate"
	end
	
	return true, nil, {
		Values = gate.Attributes,
		Schema = gate.Class.validAttributes
	}
end

local configureFunction = ReplicatedStorage.Client.Events:FindFirstChild("Configure")
configureFunction.OnServerInvoke = function(player: Player, id: number, attribute: string, value: any): (boolean, string?)
	if isCooldowned(player) then 
		log.info(player.Name .. " tried configuring a gate, but is still in cooldown")
		return false, "Too fast!"
	end

	setCooldown(player)
	log.info(player.Name .. " is requesting to configure a gate...")

	-- Failsafe against nil parameters
	if not id or not attribute or not value then
		log.warn("Failure! Nil parameters found")
		return false, "Invalid parameters! Check with a mod"
	end

	-- Validate types
	if type(id) ~= "number" then
		log.warn("Failure! 'id' parameter is not a number")
		return false, "Invalid parameters! Check with a mod"
	end
	if type(attribute) ~= "string" then
		log.warn("Failure! 'attribute' parameter is not a string")
		return false, "Invalid parameters! Check with a mod"
	end
	

	local gate = GateRegistry:tryGetGateFromId(id)
	if not gate then
		log.warn("Failure! 'id' parameter is not a registered id")
		return false, "Invalid gate! Check with a mod"
	end

	-- Validate permission for this configure
	if not PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Configure") then
		log.info("Failure! Player " .. player.Name .. " is not allowed to configure this gate")
		return false, "Lacks permissions to configure this gate"
	end
	
	if type(value) == "string" then
		local filteredValue = TextService:FilterStringAsync(value, player.UserId):GetNonChatStringForBroadcastAsync()
		value = filteredValue
	end
	
	local success = pcall(Configurer.SetAttribute, gate, attribute, value)

	if not success then
		log.warn("Error setting attribute")
		return false, "Invalid configuration"
	end

	return true, nil
end
