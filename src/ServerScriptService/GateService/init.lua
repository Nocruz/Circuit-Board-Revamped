--[[ GATE SERVICE
		Public API to interact with the whole system
		Eventually, one could just download this script as a Model
		and get the entire functionality of the game
]]

-- Requires and services
local Workspace = game:GetService("Workspace")

local Models = require(script.Models)
local Updates = require(script.Updates)
local Signals = require(script.Signals)
local Visuals = require(script.Models.Visuals)
local Attributes = require(script.Attributes)
local Connections = require(script.Connections)

-- ----------------------------- -------------- TYPE ALIASES ------------ ----------------------------

type TNodeName = string
type TAttributeName = string
type TSpecificationName = string
type TPlayerID = number
type TGateID = number

type TAttribute = string | number | boolean
type TAttributeSpecification = nil
type TSignal = Signals.TSignal
type TGateModel = Models.TGateModel

-- ----------------------------- ----------- TYPE DEFINITIONS ------------ ----------------------------

export type TNodeInstance = { [TGateID]: { [TNodeName]: true } }

export type TGateInstance = {
	Id: number,
	OwnerId: TPlayerID,
	Model: TGateModel,
	Visuals: any,
	
	Nodes: { Outputs: { [TNodeName]: TNodeInstance }, Inputs: { [TNodeName]: TNodeInstance }, Signals: { [TNodeName]: TSignal } },
	Attributes: { [TAttributeName]: TAttribute }
}

export type TSpecification = {
	Name: string,
	Nodes: { Outputs: { string }, Inputs: { string } },
	AttributeData: { [TAttributeName]: TAttributeSpecification },
	DefaultVisuals: Models.TVisuals,
	
	Setup: (gate: TGateInstance) -> (),
	Process: (self: TGateInstance) -> TSignal
}


-- ----------------------------- ----------- MODULE DEFINITION ----------- -----------------------------

local GateService = {}
local Specifications: { [TSpecificationName]: TSpecification } = {}
local Instances: { [TGateID]: TGateInstance } = {}

--[[ --------------------------- ------ SPECIFICATIONS DEFINITIONS ------- -----------------------------
	Specifications can be defined manually following the TGateSpecification signature OR
	can be created from a simple JSON like module that defines simple behaviour.
	
	The JSON is just the Nodes, AttributeData and DefaultVisuals.
	It should also hold a Process key that matches the TGateSpecification.Process signature.
]]

local specificationMetatable = { __index = {
	ReadInput = function(gate, node) return GateService.ReadInput(gate.Id, node) end,
	ReadAttribute = function(gate, attribute, node) return GateService.ReadAttribute(gate.Id, attribute, node) end,
}}

function GateService.GetSpecification(name): TSpecification?
	return Specifications[name]
end

function GateService.RegisterSpecification(name: string, specification: TSpecification)
	assert(Specifications[name] == nil, "Specification " .. name .. " was already registered")
	local data = setmetatable(specification, specificationMetatable)
	data.Name = name
	data.DefaultVisuals = Visuals.CompleteWithDefaults(data.DefaultVisuals or {}, specification.Name, #data.Nodes.Inputs, #data.Nodes.Outputs)
	data.AttributeData = specification.AttributeData or { }
	Specifications[name] = data
end

local function LoadSpecifications() 
	local specificationsFolder: Folder = script.Specifications
	for _, specification in ipairs(specificationsFolder:GetChildren()) do
		GateService.RegisterSpecification(specification.Name, require(specification))
	end
end

--[[ --------------------------- ------ GATE INSTANCE DEFINITIONS ------- -----------------------------
	GateService handles the Registry of gates (Only used for interactions Model -> Gate preferably).
	ECS may be implemented in the near future, but for now every gate will have a metatable reference to
	its GateSpecification.
	
	GateService is responsible for the creation of new gates (Because you can't instantiate Gates from the
	gates if there are no Gates). However, Gates are responsible for their own destruction and connections.
]]

local nextId: TGateID = 0

local gatesFolder = Workspace:FindFirstChild("Gates")
if not gatesFolder then
	gatesFolder = Instance.new("Folder")
	gatesFolder.Name = "Gates"
	gatesFolder.Parent = Workspace
end

local playerFolders = setmetatable({}, { __mode = "kv"} )
local function getPlayerFolder(owner: TPlayerID)
	local folderName = if owner == 0 then "Server" else tostring(owner)
	if playerFolders[folderName] then return playerFolders[folderName]
	else 
		local ownerFolder = gatesFolder:FindFirstChild(folderName)
		if ownerFolder and ownerFolder:IsA("Folder") then
			playerFolders[folderName] = ownerFolder
			return ownerFolder
		else
			local newFolder = Instance.new("Folder")
			newFolder.Name = folderName
			newFolder.Parent = gatesFolder
			playerFolders[folderName] = ownerFolder
			return newFolder
		end
	end
end

function GateService.GetGateInstance(gateID: TGateID): TGateInstance?
	return Instances[gateID]
end

function GateService.Instantiate(owner: TPlayerID, specificationName: TSpecificationName, cframe: CFrame, visuals): TGateID
	-- print("Instantiating " .. specificationName .. " with ID " .. nextID .. " at " .. tostring(cframe) .. " for " .. owner)
	
	local specification = Specifications[specificationName]
	assert(specification, "Gate specification " .. specificationName .. " has not been registered!")
	
	visuals = visuals or {}
	setmetatable(visuals, { __index = specification.DefaultVisuals} )
	
	local model: Model = Models.new(specification.Nodes, visuals)
	do
		model:PivotTo(cframe)
		model:SetAttribute("GateId", nextId)
		model.Name = specificationName
		model.Parent = getPlayerFolder(owner)
	end
	
	local gate = {}
	do	
		gate.Id = nextId
		gate.OwnerId = owner
		gate.Model = model
		gate.Nodes = { Outputs = {}, Inputs = {}, Signals = {} }
		gate.Visuals = visuals
		for _, output in ipairs(specification.Nodes.Outputs) do gate.Nodes.Outputs[output] = { }; gate.Nodes.Signals[output] = false end
		for _, input in ipairs(specification.Nodes.Inputs) do gate.Nodes.Inputs[input] = { } end
		gate.Attributes = {}
		for name, specification in pairs(specification.AttributeData) do gate.Attributes[name] = specification.Default end
		setmetatable(gate, { __index = specification } )
	end
	Instances[nextId] = gate
	
	if specification.Setup then specification.Setup(gate) end
	Updates.Propagate(nextId)

	-- BOILERPLATE FOR SWITCH AND BUTTON
	if gate.ClickDetector then gate.ClickDetector.MouseClick:Connect(function(player) GateService.Interact(gate.Id, player) end) end
	
	nextId = nextId + 1
	return nextId - 1
end

function GateService.Interact(gateID: TGateID, player: Player)
	local gate = Instances[gateID]
	assert(gate, "Gate " .. gateID .. " does not exist")
	
	Updates.Propagate(gateID, { Source = "Interaction", Player = player } )
end

function GateService.Move(gateID: TGateID, to: CFrame)
	local gate = Instances[gateID]
	assert(gate, "Gate " .. gateID .. " does not exist")
	
	gate.Model:PivotTo(to)
	
	-- Move all in connections
	for inputName, nodeInstance in pairs(gate.Nodes.Inputs) do
		for _, wire in ipairs(Connections.GetIncoming(gateID, inputName)) do
			Connections.UpdateCFrame(wire)
		end
	end
	
	-- Move all out connections
	for outputName, nodeInstance in pairs(gate.Nodes.Outputs) do
		for _, wire in ipairs(Connections.GetOutgoing(gateID, outputName)) do
			Connections.UpdateCFrame(wire)
		end
	end
end

-- Self connections are allowed!
function GateService.Connect(fromID: TGateID, toID: TGateID, Nodes: { from: TNodeName, to: TNodeName } )
	local fromGate, toGate = Instances[fromID], Instances[toID]
	assert(fromGate, "Gate " .. fromID .. " does not exist")
	assert(toGate, "Gate " .. toID .. " does not exist")
	assert(fromGate.Nodes.Outputs[Nodes.from], "Node " .. Nodes.from .. " is not in gate " .. fromID)
	assert(toGate.Nodes.Inputs[Nodes.to], "Node " .. Nodes.to .. " is not in gate " .. toID)
	
	local fromNode, toNode = fromGate.Nodes.Outputs[Nodes.from], toGate.Nodes.Inputs[Nodes.to]
	assert(not (fromNode[toID] and fromNode[toID][Nodes.to]), "Connection from Gate " .. fromID .. ", Output " .. Nodes.from .. " to Gate " .. toID .. ", Input " .. Nodes.to .. " already exists (Out triggered)")
	assert(not (toNode[fromID] and toNode[fromID][Nodes.from]), "Connection from Gate " .. fromID .. ", Output " .. Nodes.from .. " to Gate " .. toID .. ", Input " .. Nodes.to .. " already exists (In triggered)")
	
	fromNode[toID] = fromNode[toID] or {}; fromNode[toID][Nodes.to] = true
	toNode[fromID] = toNode[fromID] or {}; toNode[fromID][Nodes.from] = true
	
	local wire = Connections.new(fromID, toID, fromGate.Model.Nodes[Nodes.from], toGate.Model.Nodes[Nodes.to])
	Connections.UpdateCFrame(wire)
	
	Updates.Propagate(toID)
end

function GateService.Disconnect(fromID: TGateID, toID: TGateID, Nodes: { from: TNodeName, to: TNodeName } )
	local fromGate, toGate = Instances[fromID], Instances[toID]
	assert(fromGate, "Gate " .. fromID .. " does not exist")
	assert(toGate, "Gate " .. toID .. " does not exist")
	assert(fromGate.Nodes.Outputs[Nodes.from], "Node " .. Nodes.from .. " is not in gate " .. fromID)
	assert(toGate.Nodes.Inputs[Nodes.to], "Node " .. Nodes.to .. " is not in gate " .. toID)
	
	local fromNode, toNode = fromGate.Nodes.Outputs[Nodes.from], toGate.Nodes.Inputs[Nodes.to]
	assert(fromNode[toID] and fromNode[toID][Nodes.to], "Connection from Gate " .. fromID .. ", Output " .. Nodes.from .. " to Gate " .. toID .. ", Input " .. Nodes.to .. " does not exist (Out triggered)")
	assert(toNode[fromID] and toNode[fromID][Nodes.from], "Connection from Gate " .. fromID .. ", Output " .. Nodes.from .. " to Gate " .. toID .. ", Input " .. Nodes.to .. " does not exist (In triggered)")
	
	fromNode[toID][Nodes.to] = nil
	toNode[fromID][Nodes.from] = nil
	if next(fromNode[toID]) == nil then fromNode[toID] = nil end
	if next(toNode[fromID]) == nil then toNode[fromID] = nil end

	local wires = Connections.GetOutgoing(fromID, Nodes.from)
	for i = #wires, 1, -1 do
		local wire = wires[i]
		local matches = wire:GetAttribute("ToGate") == toID and wire:GetAttribute("ToNode") == Nodes.to
		if matches then
			Connections.Destroy(wire)
		end
	end

	Updates.Propagate(toID)
end

function GateService.Destroy(gateID: TGateID)
	local gate = Instances[gateID]
	assert(gate, "Gate " .. gateID .. " does not exist")

	Updates.CancelAllWakeups(gateID)
	
	-- Disconnect all out connections
	for outputName, nodeInstance in pairs(gate.Nodes.Outputs) do
		for toGateID, inputs in pairs(nodeInstance) do
			for inputName in pairs(inputs) do
				GateService.Disconnect(gateID, toGateID, { from = outputName, to = inputName } )
			end
			nodeInstance[toGateID] = nil
		end
	end
	
	-- Disconnect all in connections
	for inputName, nodeInstance in pairs(gate.Nodes.Inputs) do
		for fromGateID, outputs in pairs(nodeInstance) do
			for outputName in pairs(outputs) do
				GateService.Disconnect(fromGateID, gateID, { from = outputName, to = inputName } )
			end
			nodeInstance[fromGateID] = nil
		end
	end

	Instances[gateID] = nil
	gate.Model:Destroy()
end

-- INPUT READS and WRITES

function GateService.ReadAttribute(gateID: TGateID, attributeName: TAttributeName, nodeName: TNodeName?): (boolean, any)
	local gate = Instances[gateID]
	assert(gate, "Gate " .. gateID .. " does not exist")

	local attribute = gate.Attributes[attributeName]
	assert(attribute, "Gate " .. gateID .. " has no attribute " .. attributeName)

	if nodeName then
		local inputNode: TNodeInstance = gate.Nodes.Inputs[nodeName]
		assert(inputNode, "Gate " .. gateID .. " has no node " .. nodeName)

		local signals = {}
		for fromGateID, outputs in pairs(inputNode) do
			local fromGate = Instances[fromGateID]
			assert(fromGate, "Gate " .. fromGateID .. " does not exist, but is registered as input of gate " .. gateID)
			for outputNode in pairs(outputs) do
				assert(fromGate.Nodes.Outputs[outputNode], "Gate " .. fromGateID .. " is connected to " .. gateID .. " from '" .. outputNode .. "' output node, but it doesnt exist")
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
	else
		return false, attribute
	end
end

function GateService.ReadInput(gateID: TGateID, nodeName: TNodeName)
	local gate = Instances[gateID]
	assert(gate, "Gate " .. gateID .. " does not exist")
	
	local inputNode: TNodeInstance = gate.Nodes.Inputs[nodeName]
	assert(inputNode, "Gate " .. gateID .. " has no node " .. nodeName)

	local signals = {}
	for fromGateID, outputs in pairs(inputNode) do
		local fromGate = Instances[fromGateID]
		assert(fromGate, "Gate " .. fromGateID .. " does not exist, but is registered as input of gate " .. gateID)
		for outputNode in pairs(outputs) do
			assert(fromGate.Nodes.Outputs[outputNode], "Gate " .. fromGateID .. " is connected to " .. gateID .. " from '" .. outputNode .. "' output node, but it doesnt exist")
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

function GateService.TrySetAttribute(gateID: TGateID, attribute: string, value: string | number | boolean)
	local gate = Instances[gateID]
	assert(gate, "Gate " .. gateID .. " does not exist")
	assert(gate.Attributes[attribute] ~= nil, "Gate " .. gateID .. " has no attribute '" .. attribute .. "'")
	
	gate.Attributes[attribute] = Attributes.Get(value, gate.AttributeData[attribute])
	Updates.Propagate(gateID)
end


--[[ --------------------------- -------------- DEBUGGING --------------- -----------------------------]]

function GateService.VisualizeSignal(startID: TGateID, maxSteps: number?)
	maxSteps = maxSteps or 10
	
	local startGate = Instances[startID]
	assert(startGate, "Gate " .. startID .. " does not exist")
	
	print("========== SIGNAL TREE ==========")
	
	-- ===== helpers =====
	
	local function getInputs(targetId)
		local list = {}
		
		for gateId, gate in pairs(Instances) do
			for outputName, connections in pairs(gate.Nodes.Outputs) do
				for tId, nodeMap in pairs(connections) do
					if tId == targetId then
						for toNodeName in pairs(nodeMap) do
							table.insert(list, {
								id = gateId,
								label = outputName .. " -> " .. toNodeName
							})
						end
					end
				end
			end
		end
		
		return list
	end
	
	local function getOutputs(gate)
		local list = {}
		
		for outputName, connections in pairs(gate.Nodes.Outputs) do
			for targetGateId, nodeMap in pairs(connections) do
				for toNodeName in pairs(nodeMap) do
					table.insert(list, {
						id = targetGateId,
						label = outputName .. " -> " .. toNodeName
					})
				end
			end
		end
		
		return list
	end
	
	-- ===== PASS 1: DIRECT INPUTS =====
	
	local inputs = getInputs(startID)
	
	if #inputs > 0 then
		print("INCOMING")
		for _, conn in ipairs(inputs) do
			print(" | Gate " .. conn.id .. " (" .. conn.label .. ")")
		end
	end
	
	-- ===== PASS 2: OUTPUT TREE =====
	
	local visited = {}
	
	local function traverse(gateId, prefix, isLast, depth, label)
		if depth > maxSteps then return end
		
		local gate = Instances[gateId]
		if not gate then return end
		
		local connector = depth > 0 and (isLast and "└── " or "├── ") or ""
		
		-- cycle detection
		if visited[gateId] then
			print(prefix .. connector .. "↺ Gate " .. gateId)
			return
		end
		
		visited[gateId] = true
		
		if label then
			print(prefix .. connector .. "Gate " .. gateId .. " (" .. label .. ")")
		else
			print(prefix .. "Gate " .. gateId)
		end
		
		local outputs = getOutputs(gate)
		
		for i, conn in ipairs(outputs) do
			local newPrefix = prefix
			if depth > 0 then
				newPrefix = newPrefix .. (isLast and "    " or "│   ")
			end
			
			traverse(
				conn.id,
				newPrefix,
				i == #outputs,
				depth + 1,
				conn.label
			)
		end
	end
	
	-- Root + outputs
	traverse(startID, "", true, 0, nil)
	
	print("================================")
end

-- ----------------------------- ---------- LOAD SPECIFICATIONS ---------- -----------------------------

LoadSpecifications()
Updates.Initialize(Instances)

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return GateService
