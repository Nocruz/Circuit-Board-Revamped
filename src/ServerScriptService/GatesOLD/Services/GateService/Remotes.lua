--!strict
--[[ GATE SERVICE REMOTES
		Server remote surface owned by GateService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Helpers = require(script.Parent.Helpers)
local Registry = require(script.Parent.Registry)

local Remotes = {}

--- Helpers

-- ----------------------------- ------------ HELPERS ------------------- -----------------------------

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
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

local function getGate(state: any, id: any): (any, string?)
	if type(id) ~= "number" then
		return nil, "Invalid gate!"
	end

	local gate = Registry.GetById(state, id)
	if gate == nil or gate.Destroyed then
		return nil, "Invalid gate!"
	end

	return gate, nil
end

--- Public API

-- ----------------------------- ------------- PUBLIC API ------------- -----------------------------

function Remotes.Setup(state: any, publicApi: any)
	local clientFolder = ensureFolder(ReplicatedStorage, "Client")
	local gatesFolder = ensureFolder(clientFolder, "Gates")
	local queriesFolder = ensureFolder(gatesFolder, "Queries")
	local eventsFolder = ensureFolder(gatesFolder, "Events")

	state.Remotes.CanSpawn = ensureRemoteFunction(queriesFolder, "CanSpawn")
	state.Remotes.CanMove = ensureRemoteFunction(queriesFolder, "CanMove")
	state.Remotes.CanWire = ensureRemoteFunction(queriesFolder, "CanWire")
	state.Remotes.Configuration = ensureRemoteFunction(queriesFolder, "Configuration")
	state.Remotes.ClipboardList = ensureRemoteFunction(queriesFolder, "ClipboardList")
	state.Remotes.Spawn = ensureRemoteFunction(eventsFolder, "Spawn")
	state.Remotes.Move = ensureRemoteFunction(eventsFolder, "Move")
	state.Remotes.Destroy = ensureRemoteFunction(eventsFolder, "Destroy")
	state.Remotes.Connect = ensureRemoteFunction(eventsFolder, "Connect")
	state.Remotes.DisconnectAll = ensureRemoteFunction(eventsFolder, "DisconnectAll")
	state.Remotes.Disconnect = ensureRemoteFunction(eventsFolder, "Disconnect")
	state.Remotes.Configure = ensureRemoteFunction(eventsFolder, "Configure")
	state.Remotes.ClipboardSave = ensureRemoteFunction(eventsFolder, "ClipboardSave")
	state.Remotes.ClipboardRestore = ensureRemoteFunction(eventsFolder, "ClipboardRestore");

	(state.Remotes.CanSpawn :: RemoteFunction).OnServerInvoke = function(player: Player, sourceGateId: number)
		local ok, reason = Helpers.ConsumeCooldown(state, player)
		if not ok then return false, reason end

		local gate, gateError = getGate(state, sourceGateId)
		if gate == nil then return false, gateError end
		if not state.PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Spawn", gate.Specification.Name) then
			return false, "Lacks permissions to spawn this gate"
		end
		return true, nil
	end

	(state.Remotes.CanMove :: RemoteFunction).OnServerInvoke = function(player: Player, gateId: number)
		local ok, reason = Helpers.ConsumeCooldown(state, player)
		if not ok then return false, reason end

		local gate, gateError = getGate(state, gateId)
		if gate == nil then return false, gateError end
		if not state.PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Move") then
			return false, "Lacks permissions to move this gate"
		end
		return true, nil
	end

	(state.Remotes.CanWire :: RemoteFunction).OnServerInvoke = function(player: Player, gateId: number)
		local ok, reason = Helpers.ConsumeCooldown(state, player)
		if not ok then return false, reason end

		local gate, gateError = getGate(state, gateId)
		if gate == nil then return false, gateError end
		if not state.PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Wire") then
			return false, "Lacks permissions to wire this gate"
		end
		return true, nil
	end

	(state.Remotes.Configuration :: RemoteFunction).OnServerInvoke = function(player: Player, gateId: number)
		local ok, reason = Helpers.ConsumeCooldown(state, player)
		if not ok then return false, reason end

		local gate, gateError = getGate(state, gateId)
		if gate == nil then return false, gateError end
		if not state.PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Configure") then
			return false, "Lacks permissions to configure this gate"
		end
		return true, nil, publicApi.GetConfigurationData(gate)
	end

	(state.Remotes.ClipboardList :: RemoteFunction).OnServerInvoke = function(player: Player)
		local ok, reason = Helpers.ConsumeCooldown(state, player)
		if not ok then return false, reason end
		return true, nil, publicApi.ListClipboardBuilds(player.UserId)
	end

	(state.Remotes.Spawn :: RemoteFunction).OnServerInvoke = function(player: Player, sourceGateId: number, cframe: CFrame)
		local ok, reason = Helpers.ConsumeCooldown(state, player)
		if not ok then return false, reason end

		local cframeOk, cframeReason = Helpers.ValidateCFrame(cframe)
		if not cframeOk then return false, cframeReason end

		local sourceGate, gateError = getGate(state, sourceGateId)
		if sourceGate == nil then return false, gateError end
		if not state.PermissionService.canPlayerDo(player.UserId, sourceGate.OwnerId, "Spawn", sourceGate.Specification.Name) then
			return false, "Lacks permissions to spawn this gate"
		end

		publicApi.Instantiate(player.UserId, sourceGate.Specification.Name, state.GridService.fromCFrame(cframe)._cframe, publicApi.CaptureVisuals(sourceGate))
		return true, nil
	end

	(state.Remotes.Move :: RemoteFunction).OnServerInvoke = function(player: Player, gateId: number, cframe: CFrame)
		local ok, reason = Helpers.ConsumeCooldown(state, player)
		if not ok then return false, reason end

		local cframeOk, cframeReason = Helpers.ValidateCFrame(cframe)
		if not cframeOk then return false, cframeReason end

		local gate, gateError = getGate(state, gateId)
		if gate == nil then return false, gateError end
		if not state.PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Move") then
			return false, "Lacks permissions to move this gate"
		end

		publicApi.Move(gate, state.GridService.fromCFrame(cframe)._cframe)
		return true, nil
	end

	(state.Remotes.Destroy :: RemoteFunction).OnServerInvoke = function(player: Player, gateId: number)
		local ok, reason = Helpers.ConsumeCooldown(state, player)
		if not ok then return false, reason end

		local gate, gateError = getGate(state, gateId)
		if gate == nil then return false, gateError end
		if not state.PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Delete") then
			return false, "Lacks permissions to destroy this gate"
		end

		publicApi.Destroy(gate)
		return true, nil
	end

	(state.Remotes.Connect :: RemoteFunction).OnServerInvoke = function(player: Player, fromId: number, toId: number, inputName: string)
		local ok, reason = Helpers.ConsumeCooldown(state, player)
		if not ok then return false, reason end

		local fromGate, fromError = getGate(state, fromId)
		if fromGate == nil then return false, fromError end
		local toGate, toError = getGate(state, toId)
		if toGate == nil then return false, toError end

		if not state.PermissionService.canPlayerDo(player.UserId, fromGate.OwnerId, "Wire")
			or not state.PermissionService.canPlayerDo(player.UserId, toGate.OwnerId, "Wire") then
			return false, "Lacks permissions to wire this gate"
		end
		return publicApi.Connect(fromGate, toGate, inputName)
	end

	(state.Remotes.DisconnectAll :: RemoteFunction).OnServerInvoke = function(player: Player, gateId: number)
		local ok, reason = Helpers.ConsumeCooldown(state, player)
		if not ok then return false, reason end

		local gate, gateError = getGate(state, gateId)
		if gate == nil then return false, gateError end
		if not state.PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Wire") then
			return false, "Lacks permissions to disconnect this gate"
		end

		publicApi.DisconnectAll(gate)
		return true, nil
	end

	(state.Remotes.Disconnect :: RemoteFunction).OnServerInvoke = function(player: Player, fromId: number, toId: number, inputName: string)
		local ok, reason = Helpers.ConsumeCooldown(state, player)
		if not ok then return false, reason end

		local fromGate, fromError = getGate(state, fromId)
		if fromGate == nil then return false, fromError end
		local toGate, toError = getGate(state, toId)
		if toGate == nil then return false, toError end

		if not state.PermissionService.canPlayerDo(player.UserId, fromGate.OwnerId, "Wire")
			or not state.PermissionService.canPlayerDo(player.UserId, toGate.OwnerId, "Wire") then
			return false, "Lacks permissions to cut this wire"
		end
		return publicApi.Disconnect(fromGate, toGate, inputName)
	end

	(state.Remotes.Configure :: RemoteFunction).OnServerInvoke = function(player: Player, gateId: number, attributeName: string, value: any)
		local ok, reason = Helpers.ConsumeCooldown(state, player)
		if not ok then return false, reason end

		local gate, gateError = getGate(state, gateId)
		if gate == nil then return false, gateError end
		if not state.PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Configure") then
			return false, "Lacks permissions to configure this gate"
		end

		if type(value) == "string" then
			value = Helpers.FilterText(player, value, 128)
		end

		local success = pcall(function()
			publicApi.SetAttribute(gate, attributeName, value)
		end)

		if not success then
			return false, "Invalid configuration"
		end
		return true, nil
	end

	(state.Remotes.ClipboardSave :: RemoteFunction).OnServerInvoke = function(player: Player, rawTitle: string, cornerA: Vector3, cornerB: Vector3)
		local ok, reason = Helpers.ConsumeCooldown(state, player)
		if not ok then return false, reason end
		if type(rawTitle) ~= "string" then return false, "Invalid title" end

		local aOk, aReason = Helpers.ValidateVector3(cornerA)
		if not aOk then return false, aReason end
		local bOk, bReason = Helpers.ValidateVector3(cornerB)
		if not bOk then return false, bReason end

		return publicApi.SaveClipboardSelection(player, Helpers.FilterText(player, rawTitle, 32), cornerA, cornerB)
	end

	(state.Remotes.ClipboardRestore :: RemoteFunction).OnServerInvoke = function(player: Player, rawTitle: string, anchorCFrame: CFrame)
		local ok, reason = Helpers.ConsumeCooldown(state, player)
		if not ok then return false, reason end
		if type(rawTitle) ~= "string" then return false, "Invalid title" end

		local cframeOk, cframeReason = Helpers.ValidateCFrame(anchorCFrame)
		if not cframeOk then return false, cframeReason end

		return publicApi.RestoreClipboardSelection(player, rawTitle, state.GridService.fromCFrame(anchorCFrame)._cframe)
	end
end

return Remotes
