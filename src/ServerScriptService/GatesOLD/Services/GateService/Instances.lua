--!strict
--[[ GATE SERVICE INSTANCES
		Gate instance lifecycle, methods, and runtime mutations.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local AttributeService = require(ServerScriptService.Gates.Services.AttributeService)
local GateModel = require(ServerScriptService.Gates.Definitions.GateModel)
local SignalService = require(ServerScriptService.Gates.Services.SignalService)

local Helpers = require(script.Parent.Helpers)
local Registry = require(script.Parent.Registry)
local Wires = require(script.Parent.Wires)

local Instances = {}

--- Helpers

-- ----------------------------- ------------ HELPERS ------------------- -----------------------------

local function getModelClassLike(specification: any): any
	return {
		name = specification.Name,
		inputs = specification.Nodes.InputOrder,
		output = if specification.Nodes.HasOutput then "Output" else nil,
	}
end

local function getSignalInput(node: any): any
	if node == nil or next(node) == nil then
		return false
	end

	local signals = {}
	for fromGate in pairs(node) do
		if fromGate.Output ~= nil then
			table.insert(signals, fromGate.Output)
		end
	end

	return SignalService.Collapse(signals)
end

local function getAttributeDefault(specification: any, attributeName: string): any
	local attribute = specification.Attributes[attributeName]
	return if attribute ~= nil then attribute.Default else nil
end

local function callConnectionChanged(gate: any)
	local callback = gate.Specification.OnConnectionChanged
	if callback ~= nil then
		callback(gate)
	end
end

local function buildInstanceMetatable(publicApi: any)
	local methods = {}

	function methods:GetSignalInput(inputName: string): any
		return getSignalInput(self.Inputs[inputName])
	end

	function methods:GetAttributeValue(attributeName: string): any
		local node = self.Inputs[attributeName]
		if node ~= nil and next(node) ~= nil then
			return getSignalInput(node)
		end

		local storedValue = self.Attributes[attributeName]
		if storedValue ~= nil then
			return storedValue
		end

		return getAttributeDefault(self.Specification, attributeName)
	end

	function methods:Schedule(delay: number)
		publicApi.Schedule(self, delay)
	end

	function methods:Destroy()
		publicApi.Destroy(self)
	end

	function methods:ConnectTo(target: any, inputName: string): (boolean, string?)
		return publicApi.Connect(self, target, inputName)
	end

	function methods:DisconnectFrom(target: any, inputName: string): (boolean, string?)
		return publicApi.Disconnect(self, target, inputName)
	end

	return { __index = methods }
end

local function normalizeGateInstance(publicApi: any, specification: any, id: number, ownerId: number, model: Model): any
	local gate = {
		Id = id,
		OwnerId = ownerId,
		Specification = specification,
		Model = model,
		Output = nil,
		Incoming = {},
		Outgoing = nil,
		Inputs = {},
		Connections = nil,
		Attributes = {},
		State = {},
		Destroyed = false,
	}

	for _, inputName in ipairs(specification.Nodes.InputOrder) do
		gate.Inputs[inputName] = {}
	end
	gate.Incoming = gate.Inputs

	if specification.Nodes.HasOutput then
		gate.Output = false
		gate.Connections = {}
		gate.Outgoing = gate.Connections
	end

	for attributeName, attribute in pairs(specification.Attributes) do
		gate.Attributes[attributeName] = attribute.Default
	end

	setmetatable(gate, buildInstanceMetatable(publicApi))
	return gate
end

local function updateModelAttributes(gate: any)
	gate.Model:SetAttribute("GateId", gate.Id)
	gate.Model:SetAttribute("OwnerId", gate.OwnerId)
	gate.Model:SetAttribute("SpecificationName", gate.Specification.Name)
end

--- Public API

-- ----------------------------- ------------- PUBLIC API ------------- -----------------------------

function Instances.Instantiate(state: any, publicApi: any, specificationName: string, ownerId: number, cframe: CFrame, visualsOverride: any?): any
	local specification = Registry.GetSpecification(state, specificationName)
	assert(specification ~= nil, "Gate specification '" .. specificationName .. "' is not registered")
	
	local visuals = Helpers.CloneVisuals(visualsOverride or specification.DefaultVisuals)
	local model = GateModel.Instantiate(getModelClassLike(specification), visuals, cframe)
	model.Parent = Helpers.GetPlayerFolder(state, ownerId)
	
	state.NextGateId += 1
	local gate = normalizeGateInstance(publicApi, specification, state.NextGateId, ownerId, model)
	
	if specification.Create ~= nil then
		specification.Create(gate)
	end
	
	updateModelAttributes(gate)
	Registry.AddGate(state, gate)
	publicApi.Propagate(gate)
	return gate
end

function Instances.Connect(state: any, publicApi: any, fromGateOrId: any, toGateOrId: any, inputName: string): (boolean, string?)
	local fromGate = if type(fromGateOrId) == "number" then Registry.GetById(state, fromGateOrId) else fromGateOrId
	local toGate = if type(toGateOrId) == "number" then Registry.GetById(state, toGateOrId) else toGateOrId

	if fromGate == nil or toGate == nil or fromGate.Destroyed or toGate.Destroyed then
		return false, "Invalid gate!"
	end
	if fromGate.Connections == nil then
		return false, "Source gate has no output"
	end

	local inputNode = toGate.Inputs[inputName]
	if inputNode == nil then
		return false, "Invalid input!"
	end

	local existing = fromGate.Connections[toGate]
	if existing ~= nil and existing[inputName] ~= nil then
		return false, "Already connected"
	end

	inputNode[fromGate] = true
	fromGate.Connections[toGate] = fromGate.Connections[toGate] or {}
	fromGate.Connections[toGate][inputName] = {
		WireId = Wires.Create(state, fromGate, toGate, inputName),
	}

	callConnectionChanged(fromGate)
	callConnectionChanged(toGate)
	publicApi.Propagate(toGate)
	return true, nil
end

function Instances.Disconnect(state: any, publicApi: any, fromGateOrId: any, toGateOrId: any, inputName: string): (boolean, string?)
	local fromGate = if type(fromGateOrId) == "number" then Registry.GetById(state, fromGateOrId) else fromGateOrId
	local toGate = if type(toGateOrId) == "number" then Registry.GetById(state, toGateOrId) else toGateOrId

	if fromGate == nil or toGate == nil then
		return false, "Invalid gate!"
	end

	local connectionMap = fromGate.Connections and fromGate.Connections[toGate]
	local connection = connectionMap and connectionMap[inputName]
	if connection == nil then
		return false, "Invalid wire!"
	end

	toGate.Inputs[inputName][fromGate] = nil
	if connection.WireId ~= nil then
		Wires.Destroy(state, connection.WireId)
	end

	connectionMap[inputName] = nil
	if next(connectionMap) == nil then
		fromGate.Connections[toGate] = nil
	end

	callConnectionChanged(fromGate)
	callConnectionChanged(toGate)
	publicApi.Propagate(toGate)
	return true, nil
end

function Instances.DisconnectAll(state: any, publicApi: any, gateOrId: any)
	local gate = if type(gateOrId) == "number" then Registry.GetById(state, gateOrId) else gateOrId
	if gate == nil then
		return
	end

	if gate.Connections ~= nil then
		local outgoing = {}
		for targetGate, inputMap in pairs(gate.Connections) do
			for inputName in pairs(inputMap) do
				table.insert(outgoing, { Target = targetGate, InputName = inputName })
			end
		end
		for _, connection in ipairs(outgoing) do
			publicApi.Disconnect(gate, connection.Target, connection.InputName)
		end
	end

	for inputName, node in pairs(gate.Inputs) do
		local incoming = {}
		for fromGate in pairs(node) do
			table.insert(incoming, fromGate)
		end
		for _, fromGate in ipairs(incoming) do
			publicApi.Disconnect(fromGate, gate, inputName)
		end
	end
end

function Instances.Destroy(state: any, publicApi: any, gateOrId: any)
	local gate = if type(gateOrId) == "number" then Registry.GetById(state, gateOrId) else gateOrId
	if gate == nil or gate.Destroyed then
		return
	end

	gate.Destroyed = true
	publicApi.Cancel(gate)
	publicApi.DisconnectAll(gate)

	if gate.Specification.OnDestroy ~= nil then
		gate.Specification.OnDestroy(gate)
	end

	Registry.RemoveGate(state, gate)
	gate.Model:Destroy()
end

function Instances.Move(state: any, gateOrId: any, cframe: CFrame)
	local gate = if type(gateOrId) == "number" then Registry.GetById(state, gateOrId) else gateOrId
	if gate == nil or gate.Destroyed then
		return
	end

	gate.Model:PivotTo(cframe)

	local gateWires = state.WiresByGate[gate.Id]
	if gateWires ~= nil then
		for wireId in pairs(gateWires) do
			Wires.UpdateHitbox(state, wireId)
		end
	end
end

function Instances.SetAttribute(state: any, publicApi: any, gateOrId: any, attributeName: string, value: any): any
	local gate = if type(gateOrId) == "number" then Registry.GetById(state, gateOrId) else gateOrId
	if gate == nil then
		return nil
	end

	local attribute = gate.Specification.Attributes[attributeName]
	if attribute == nil then
		error("Unknown attribute '" .. attributeName .. "'")
	end

	gate.Attributes[attributeName] = AttributeService.ValueOrDefault(attribute, value)
	publicApi.Propagate(gate)
	return gate.Attributes[attributeName]
end

function Instances.GetConfigurationData(state: any, gateOrId: any): any
	local gate = if type(gateOrId) == "number" then Registry.GetById(state, gateOrId) else gateOrId
	assert(gate ~= nil, "Gate not found")

	return {
		Values = Helpers.CloneAttributeValues(gate.Attributes),
		Schema = AttributeService.ToClientSchema(gate.Specification.Attributes),
	}
end

function Instances.CaptureVisuals(gate: any): any
	local visuals = Helpers.CloneVisuals(gate.Specification.DefaultVisuals)
	local decoration = gate.Model:FindFirstChild("Decoration")
	local main = decoration and decoration:FindFirstChild("Main")
	if main and main:IsA("BasePart") then
		visuals.MainColor = main.Color
		visuals.MainMaterial = main.Material
	end

	local displayName = gate.Model:GetAttribute("DisplayName")
	if type(displayName) == "string" and displayName ~= "" then
		visuals.DisplayName = displayName
	end

	local prefabName = gate.Model:GetAttribute("PrefabName")
	if type(prefabName) == "string" and prefabName ~= "" then
		visuals.PrefabName = prefabName
	end

	return visuals
end

return Instances
