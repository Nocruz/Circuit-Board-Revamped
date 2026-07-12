--[[ GATE SERVICE
		Public API to interact with the whole system.
		Handles coordination between submodules.
		Works as a plug-and-play for the game.
]]

-- Requires and Services
local GatesHandler = require(script.Handlers.GatesHandler)
local SpecificationsHandler = require(script.Handlers.SpecificationsHandler)

local Models = require(script.Models)
local Connections = require(script.Connections)
local Updates = require(script.Updates)
local Signals = require(script.Signals)

-- ----------------------------- ----------- MODULE DEFINITION ----------- -----------------------------

local GateService = {}

-- ----------------------------- -------- SPECIFICATION FUNCTIONS -------- -----------------------------

function GateService.RegisterSpecification(specification, name: string?)
	if (SpecificationsHandler.Get(specification.Name)) then return warn("Specification of name " .. specification.Name .. " has already been registered") end
	
	specification.Name = name or specification.Name or error("No name assigned to the specification")
	specification.DefaultVisuals = Models.GetSpecificationVisualsTable(specification.DefaultVisuals or {}, specification.Name, #specification.Nodes.Inputs, #specification.Nodes.Outputs)
	specification.AttributeData = specification.AttributeData or { }
	
	SpecificationsHandler.Add(specification)
	return
end

-- ----------------------------- ------------ GATE SUPERCLASS ------------ -----------------------------

local SUPERCLASS_GATE = { }

function SUPERCLASS_GATE:ReadInput(nodeName: string)
	local incoming = Connections.GetAllIncoming(self.ID, nodeName)
	
	local signals = {}
	for fromGateID, connections in pairs(incoming) do
		local fromGate = GatesHandler.Get(fromGateID)
		assert(fromGate, "Gate " .. fromGateID .. " does not exist, but is registered as input of gate " .. self.ID)
		for outputNode in pairs(connections) do
			assert(fromGate.Nodes.Outputs[outputNode], "Gate " .. fromGateID .. " is connected to " .. self.ID .. " from '" .. outputNode .. "' output node, but it doesnt exist")
			assert(fromGate.Nodes.Signals[outputNode] ~= nil, "Gate " .. fromGateID .. " is missing '" .. outputNode .. "' output node key in Signals table")
			table.insert(signals, fromGate.Nodes.Signals[outputNode])
		end
	end
	
	local raw = Signals.Collapse(signals)
	return {
		Raw = raw,
		AsString = function() return Signals.toString(raw) end,
		AsNumber = function() return Signals.toNumber(raw) end,
		AsBoolean = function() return Signals.toBoolean(raw) end
	}
end

function SUPERCLASS_GATE:ReadAttributeFromNode(attributeName: string, nodeName: string)
	local attribute = self.Attributes[attributeName]
	assert(attribute ~= nil, "Gate " .. self.ID .. " has no attribute " .. attributeName)
	assert(table.find(self.Specification.Nodes.Inputs, nodeName), "Gate " .. self.ID .. " has no node " .. nodeName)
	
	local inputConnections = Connections.GetAllIncoming(self.ID, nodeName)
	
	local signals = {}
	for fromGateID, connections in pairs(inputConnections) do
		local fromGate = GatesHandler.Get(fromGateID)
		assert(fromGate, "Gate " .. fromGateID .. " does not exist, but is registered as input of gate " .. self.ID)
		for outputNode in pairs(connections) do
			assert(fromGate.Nodes.Outputs[outputNode], "Gate " .. fromGateID .. " is connected to " .. self.ID .. " from '" .. outputNode .. "' output node, but it doesnt exist")
			assert(fromGate.Nodes.Signals[outputNode] ~= nil, "Gate " .. fromGateID .. " is missing '" .. outputNode .. "' output node key in Signals table")
			table.insert(signals, fromGate.Nodes.Signals[outputNode])
		end
	end
	
	if next(signals) == nil then return false, attribute end
	
	local raw = Signals.Collapse(signals)
	return true, {
		Raw = raw,
		AsString = function() return Signals.toString(raw) end,
		AsNumber = function() return Signals.toNumber(raw) end,
		AsBoolean = function() return Signals.toBoolean(raw) end
	}
end

-- ----------------------------- ----------- INSTANCE FUNCTIONS ---------- -----------------------------

local nextID = 1

local function instantiateGate(ownerID: number, specificationName: string, cframe: CFrame, visuals, attributes, state: { Signals: any, Internal: any } | any): number
	local specification = SpecificationsHandler.Get(specificationName)
	local solvedVisuals = setmetatable(table.clone(visuals or {}), { __index = specification.DefaultVisuals })
	attributes = attributes or {}
	state = state or {}
	
	local model: Model = Models.new(specification.Nodes, solvedVisuals) do
		model:PivotTo(cframe)
		model:SetAttribute("GateID", nextID)
		model:SetAttribute("OwnerID", ownerID)
		model.Name = specification.Name
		model.Parent = if ownerID == 0 then workspace.Gates.Server else workspace.Gates[ownerID] -- Should be set by caller
	end
	
	local gate = {} do
		gate.ID = nextID
		gate.OwnerID = ownerID
		gate.Model = model
		gate.Specification = specification
		gate.Visuals = solvedVisuals
		gate.InternalState = {}
		
		gate.Nodes = { Outputs = {}, Inputs = {}, Signals = {} }
		for _, output in ipairs(specification.Nodes.Outputs) do gate.Nodes.Outputs[output] = { }; gate.Nodes.Signals[output] = if (state.Signals ~= nil and state.Signals[output] ~= nil) then state.Signals[output] else false end
		for _, input in ipairs(specification.Nodes.Inputs) do gate.Nodes.Inputs[input] = { } end
		
		gate.Attributes = {}
		for name, attributeData in pairs(specification.AttributeData) do gate.Attributes[name] = if attributes[name] ~= nil then attributes[name] else attributeData.Default end
		
		setmetatable(gate, { __index = SUPERCLASS_GATE })
	end
	
	GatesHandler.Add(nextID, gate)
	
	if specification.Setup then specification.Setup(gate, state) end
	
	nextID = nextID + 1
	return nextID - 1	
end

--- Instantiates a new Gate, and returns its ID
--- Assumes all parameters are valid
function GateService.Instantiate(ownerID: number, specificationName: string, cframe: CFrame, visuals, attributes): number
	local id = instantiateGate(ownerID, specificationName, cframe, visuals, attributes, nil)
	Updates.Propagate(id)
	return id
end

function GateService.Destroy(gateID: number)
	local gate = GatesHandler.Get(gateID)
	if gate == nil then
		warn("Tried to destroy gate of ID " .. gateID .. ", but it doesn't exist")
		return
	end
	
	Updates.CancelAllWakeups(gateID)
	
	local affected = Connections.DestroyAll(gateID)
	for _, gateID in ipairs(affected) do
		Updates.Propagate(gateID)
	end
	
	if gate.Specification.Destroy then gate.Specification.Destroy(gate) end
	
	GatesHandler.Remove(gateID)
	
	gate.Model:Destroy()
end

function GateService.Move(gateID: number, cframe: CFrame)
	local gate = GatesHandler.Get(gateID)
	if gate == nil then
		warn("Tried to move gate of ID " .. gateID .. ", but it doesn't exist")
		return
	end
	
	gate.Model:PivotTo(cframe)
	
	Connections.UpdateAllWireHitboxes(gateID)
end

function GateService.Connect(fromGateID: number, toGateID: number, fromNode: string, toNode: string): (boolean, string?)
	local fromGate, toGate = GatesHandler.Get(fromGateID), GatesHandler.Get(toGateID)
	
	-- Existance validation
	if fromGate == nil then
		warn("Tried to connect gate of ID " .. fromGateID ..", but it doesn't exist")
		return false
	end
	if toGate == nil then
		warn("Tried to connect gate of ID " .. toGateID ..", but it doesn't exist")
		return false
	end
	if table.find(fromGate.Specification.Nodes.Outputs, fromNode) == nil then
		warn("Tried to connect node \"" .. fromNode .. "\" of a gate of specification \"" .. fromGate.Specification.Name .. "\" (" .. fromGateID .. "), despite it not having any Output Node with that name.")
		return false
	end
	if table.find(toGate.Specification.Nodes.Inputs, toNode) == nil then
		warn("Tried to connect node \"" .. toNode .. "\" of a gate of specification \"" .. toGate.Specification.Name .. "\" (" .. toGateID .. "), despite it not having any Input Node with that name.")
		return false
	end

	-- Are they already connected?
	if Connections.Get(fromGateID, toGateID, fromNode, toNode) ~= nil then
		return false, "These nodes are already connected"
	end
	
	local wire = Connections.new(fromGateID, toGateID, fromGate.Model.Nodes.Outputs[fromNode], toGate.Model.Nodes.Inputs[toNode])
	
	Updates.RegisterVisualChange(wire, { Color = ColorSequence.new(if Signals.toBoolean(fromGate.Nodes.Signals[fromNode]) then Color3.new(0.9, 0.9, 1) else Color3.new(0, 0, 0.1)) })
	Updates.Propagate(toGateID)
	
	return true
end

function GateService.Disconnect(fromGateID: number, toGateID: number, fromNode: string, toNode: string): (boolean, string?)
	local fromGate, toGate = GatesHandler.Get(fromGateID), GatesHandler.Get(toGateID)
	
	-- Existance validation
	if fromGate == nil then
		warn("Tried to connect gate of ID " .. fromGateID ..", but it doesn't exist")
		return false
	end
	if toGate == nil then
		warn("Tried to connect gate of ID " .. toGateID ..", but it doesn't exist")
		return false
	end
	if table.find(fromGate.Specification.Nodes.Outputs, fromNode) == nil then
		warn("Tried to connect node \"" .. fromNode .. "\" of a gate of specification \"" .. fromGate.Specification.Name .. "\" (" .. fromGateID .. "), despite it not having any Output Node with that name.")
		return false
	end
	if table.find(toGate.Specification.Nodes.Inputs, toNode) == nil then
		warn("Tried to connect node \"" .. toNode .. "\" of a gate of specification \"" .. toGate.Specification.Name .. "\" (" .. toGateID .. "), despite it not having any Input Node with that name.")
		return false
	end
	
	-- Are they not already connected?
	if Connections.Get(fromGateID, toGateID, fromNode, toNode) == nil then
		return false, "These nodes are not connected!"
	end
	
	Connections.Destroy(fromGateID, toGateID, fromNode, toNode)
	
	Updates.Propagate(toGateID)
	
	return true
end

function GateService.Load(playerID: number, saveData, loadCFrame: CFrame): (boolean, string?)
	-- Instantiate
	local offsetIDToRealIDs = {} 
	for offsetID, data in ipairs(saveData.G) do
		local realID = instantiateGate(playerID, data.Specification, loadCFrame:toWorldSpace(data.CFrame._cframe), {}, data.Attributes, data.State)
		offsetIDToRealIDs[offsetID] = realID
	end
	
	-- Connect
	for offsetID, outConnections in pairs(saveData.C) do
		local from = GatesHandler.Get(offsetIDToRealIDs[offsetID])
		for outputName, inGates in pairs(outConnections) do
			for inGateID, nodes in pairs(inGates) do
				inGateID = tonumber(inGateID) -- Blame Roblox's dumb serialization for this
				local to = GatesHandler.Get(offsetIDToRealIDs[inGateID])
				for _, inputName in ipairs(nodes) do
					local wire = Connections.new(offsetIDToRealIDs[offsetID], offsetIDToRealIDs[inGateID], from.Model.Nodes.Outputs[outputName], to.Model.Nodes.Inputs[inputName])
					Updates.RegisterVisualChange(wire, { Color = ColorSequence.new(if Signals.toBoolean(from.Nodes.Signals[outputName]) then Color3.new(0.9, 0.9, 1) else Color3.new(0, 0, 0.1)) })
				end
			end
		end
	end
	
	-- Propagate
	for _, id in pairs(offsetIDToRealIDs) do
		Updates.Propagate(id)
	end
	
	return true
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return GateService
