--!strict
--[[ GATE SERVICE
		Public facade for the self-contained gate runtime.
]]

-- Internal Services
local Clipboard = require(script.Clipboard)
local Instances = require(script.Instances)
local Registry = require(script.Registry)
local Remotes = require(script.Remotes)
local Specifications = require(script.Specifications)
local StateFactory = require(script.State)
local Types = require(script.Types)
local Updates = require(script.Updates)

local GateService = {
	Specifications = Specifications,
	Types = Types,
}

local state = StateFactory.new()

--- Public API

-- ----------------------------- ------------- PUBLIC API ------------- -----------------------------

function GateService.RegisterSpecification(name: string, specification: any)
	Registry.RegisterSpecification(state, name, specification)
end

function GateService.GetSpecification(name: string): any
	return Registry.GetSpecification(state, name)
end

function GateService.GetById(id: number): any
	return Registry.GetById(state, id)
end

function GateService.GetByModel(modelOrInstance: Instance): any
	return Registry.GetByModel(state, modelOrInstance)
end

function GateService.Propagate(gateOrId: any)
	Updates.Propagate(state, gateOrId)
end

function GateService.Cancel(gateOrId: any)
	Updates.Cancel(state, gateOrId)
end

function GateService.Schedule(gateOrId: any, delay: number)
	Updates.Schedule(state, gateOrId, delay)
end

function GateService.Instantiate(ownerId: number, specificationName: string, cframe: CFrame, visualsOverride: any?): any
	return Instances.Instantiate(state, GateService, specificationName, ownerId, cframe, visualsOverride)
end

function GateService.Connect(fromGateOrId: any, toGateOrId: any, inputName: string): (boolean, string?)
	return Instances.Connect(state, GateService, fromGateOrId, toGateOrId, inputName)
end

function GateService.Disconnect(fromGateOrId: any, toGateOrId: any, inputName: string): (boolean, string?)
	return Instances.Disconnect(state, GateService, fromGateOrId, toGateOrId, inputName)
end

function GateService.DisconnectAll(gateOrId: any)
	Instances.DisconnectAll(state, GateService, gateOrId)
end

function GateService.Destroy(gateOrId: any)
	Instances.Destroy(state, GateService, gateOrId)
end

function GateService.Move(gateOrId: any, cframe: CFrame)
	Instances.Move(state, gateOrId, cframe)
end

function GateService.SetAttribute(gateOrId: any, attributeName: string, value: any): any
	return Instances.SetAttribute(state, GateService, gateOrId, attributeName, value)
end

function GateService.GetConfigurationData(gateOrId: any): any
	return Instances.GetConfigurationData(state, gateOrId)
end

function GateService.CaptureVisuals(gate: any): any
	return Instances.CaptureVisuals(gate)
end

function GateService.ListClipboardBuilds(userId: number): { any }
	return Clipboard.ListBuilds(state, userId)
end

function GateService.SerializeSelection(userId: number, cornerA: Vector3, cornerB: Vector3): (boolean, string?, any?)
	return Clipboard.SerializeSelection(state, GateService, userId, cornerA, cornerB)
end

function GateService.RestoreBuild(userId: number, build: any, anchorCFrame: CFrame): (boolean, string?)
	return Clipboard.RestoreBuild(state, GateService, userId, build, anchorCFrame)
end

function GateService.SaveClipboardSelection(player: Player, rawTitle: string, cornerA: Vector3, cornerB: Vector3): (boolean, string?, { any }?)
	return Clipboard.SaveSelection(state, GateService, player, rawTitle, cornerA, cornerB)
end

function GateService.RestoreClipboardSelection(player: Player, rawTitle: string, anchorCFrame: CFrame): (boolean, string?, { any }?)
	return Clipboard.RestoreSelection(state, GateService, player, rawTitle, anchorCFrame)
end

function GateService.Start(deps: { PermissionService: any?, GridService: any? }?)
	if state.Started then
		return GateService
	end

	if deps ~= nil then
		state.PermissionService = deps.PermissionService or state.PermissionService
		state.GridService = deps.GridService or state.GridService
	end

	local registeredSpecifications = Specifications.RegisterAll(GateService)
	Remotes.Setup(state, GateService)
	Updates.Start(state, log)
	state.Started = true
	log.info(string.format("Registered %d GateService specification(s)", registeredSpecifications))
	log.info("GateService started")

	return GateService
end

return GateService
