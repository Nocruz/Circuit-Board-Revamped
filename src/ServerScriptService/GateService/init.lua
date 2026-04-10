--[[ GATE SERVICE
		Public API to interact with the whole system
		Eventually, one could just download this script as a Model
		and get the entire functionality of the game
]]

-- Requires and services
local Workspace = game:GetService("Workspace")

-- local Attributes = require(script.Attributes)
-- local Updates = require(script.Updates)
-- local Signals = require(script.Signals)
local Models = require(script.Models)
local Visuals = require(script.Models.Visuals)
local Connections = require(script.Connections)

-- ----------------------------- -------------- TYPE ALIASES ------------ ----------------------------

type TNodeName = string
type TAttributeName = string
type TSpecificationName = string
type TPlayerID = number
type TGateID = number

type TAttribute = string | number | boolean
type TAttributeSpecification = nil
type TSignal = nil
type TGateModel = Models.TGateModel

-- ----------------------------- ----------- TYPE DEFINITIONS ------------ ----------------------------

export type TNodeInstance = { [TGateID]: { [TNodeName]: true } }

export type TGateInstance = {
	OwnerId: TPlayerID,
	Model: TGateModel,
	
	Nodes: { Outputs: { [TNodeName]: TNodeInstance }, Inputs: { [TNodeName]: TNodeInstance } },
	Attributes: { [TAttributeName]: TAttribute },
}

export type TGateSpecification = {
	Nodes: { Outputs: { string }, Inputs: { string } },
	AttributeData: { [TAttributeName]: TAttributeSpecification },
	DefaultVisuals: Models.TVisuals,
	
	Create: (specification: TGateSpecification, owner: TPlayerID, model: TGateModel) -> TGateInstance,
	Process: (self: TGateInstance) -> TSignal
}

-- ----------------------------- ----------- MODULE DEFINITION ----------- -----------------------------

local GateService = {}

--[[ --------------------------- ------ SPECIFICATIONS DEFINITIONS ------- -----------------------------
	Specifications can be defined manually following the TGateSpecification signature OR
	can be created from a simple JSON like module that defines simple behaviour.
	
	The JSON is just the Nodes, AttributeData and DefaultVisuals.
	It should also hold a Process key that matches the TGateSpecification.Process signature.
]]

local Specifications: { [TSpecificationName]: TGateSpecification } = {}

function GateService.GetSpecification(name): TGateSpecification?
	return Specifications[name]
end

function GateService.RegisterSpecification(name: TSpecificationName, specification: TGateSpecification)
	Specifications[name] = specification
end

local specificationsFolder: Folder = script.Specifications
for _, specification in ipairs(specificationsFolder:GetChildren()) do
	local data = require(specification)
	data.DefaultVisuals = Visuals.CompleteWithDefaults(data.DefaultVisuals, specification.Name, #data.Nodes.Inputs, #data.Nodes.Outputs)
	GateService.RegisterSpecification(specification.Name, data)
end

--[[ --------------------------- ------ GATE INSTANCE DEFINITIONS ------- -----------------------------
	GateService handles the Registry of gates (Only used for interactions Model -> Gate preferably).
	ECS may be implemented in the near future, but for now every gate will have a metatable reference to
	its GateSpecification.
	
	GateService is responsible for the creation of new gates (Because you can't instantiate Gates from the
	gates if there are no Gates). However, Gates are responsible for their own destruction and connections.
]]

local nextID: TGateID = 0
local Instances: { [TGateID]: TGateInstance } = {}

local gatesFolder = Workspace.Gates
local playerFolders = {} -- Not weak table because Workspace will always have the folder registered
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

function GateService.InstantiateGate(owner: TPlayerID, specificationName: TSpecificationName, cframe: CFrame, visuals): TGateID
	-- print("Instantiating " .. specificationName .. " with ID " .. nextID .. " at " .. tostring(cframe) .. " for " .. owner)
	
	local specification = Specifications[specificationName]
	assert(specification, "Gate specification " .. specificationName .. " has not been registered!")
	
	visuals = visuals or {}
	setmetatable(visuals, { __index = specification.DefaultVisuals} )
	
	local model: Model = Models.new(specification.Nodes, visuals)
	model:PivotTo(cframe)
	model:SetAttribute("GateId", nextID)
	model.Name = specificationName
	model.Parent = getPlayerFolder(owner)
	
	local gate = specification:Create(owner, model) -- Sets metatable to it's specification
	Instances[nextID] = gate
	
	nextID = nextID + 1
	return nextID - 1
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
	
	local wire = Connections.new(fromGate.Model.Nodes[Nodes.from], toGate.Model.Nodes[Nodes.to])
	wire.Parent = fromGate.Model.Nodes[Nodes.from]
	wire.Name = toID .. "-" .. Nodes.to
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
	
	local wire = fromGate.Model.Nodes[Nodes.from][toID .. "-" .. Nodes.to]
	wire:Destroy()
end

function GateService.Destroy(gateID: TGateID)
	local gate = Instances[gateID]
	assert(gate, "Gate " .. gateID .. " does not exist")
	
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

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return GateService
