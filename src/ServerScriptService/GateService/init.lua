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
local Attributes = require(script.Attributes)
local Connections = require(script.Connections)

-- ----------------------------- ------------- TYPE ALIASES -------------- -----------------------------

type TNodeName = string
type TAttributeName = string
type TSpecificationName = string
type TPlayerID = number
type TGateID = number

type TAttribute = string | number | boolean
type TAttributeSpecification = nil
type TSignal = Signals.TSignal
type TGateModel = Models.TGateModel
type TModelType = Models.TModelType
type TVisuals = Models.TVisuals

-- ----------------------------- ----------- TYPE DEFINITIONS ------------ -----------------------------

export type TGateInstance = {
	Id: number,
	OwnerId: TPlayerID,
	Model: TGateModel,
	
	-- Stores the current value of the Output nodes
	Signals: { [TNodeName]: TSignal },
	Attributes: { [TAttributeName]: TAttribute }
}

export type TSpecification = {
	Name: string,
	Nodes: { Outputs: { string }, Inputs: { string } },
	AttributeData: { [TAttributeName]: TAttributeSpecification },
	DefaultVisuals: TVisuals,
	ModelType: TModelType,
	
	Setup: (gate: TGateInstance) -> (),
	Process: (self: TGateInstance) -> ()
}

-- ----------------------------- ---------- MODULE DEFINITION ------------ -----------------------------

local GateService = {}
local Specifications --[[: { [TSpecificationName]: TSpecification }]] = {}
local Instances --[[: { [TGateID]: TGateInstance }]] = {}

-- ----------------------------- ------ SPECIFICATIONS DEFINITIONS ------- -----------------------------
-- Specifications are actually a gate instance's metatable. As such, the 'BaseGateUtils' holds the methods
--   any gate should have.

local BaseGateUtils = { __index = {
	ReadInput = function(gate, node) return GateService.ReadInput(gate.Id, node) end,
	ReadAttribute = function(gate, attribute, node) return GateService.ReadAttributeFromNode(gate.Id, attribute, node) end,
}}

function GateService.GetSpecification(name): TSpecification?
	return Specifications[name]
end

function GateService.RegisterSpecification(name: string, specification: TSpecification)
	assert(Specifications[name] == nil, "Can't register specification \"" .. name .. "\". Reason: Registry under that name already exists.")
	assert(specification ~= nil and specification.Nodes ~= nil, "Can't register specification \"" .. name .. "\". Reason: Specification does not have necessary field: Nodes")
	assert(specification.Nodes.Inputs ~= nil, "Can't register specification \"" .. name .. "\". Reason: Specification does not have necessary field: Nodes.Inputs")
	assert(specification.Nodes.Outputs ~= nil, "Can't register specification \"" .. name .. "\". Reason: Specification does not have necessary field: Nodes.Outputs")
	
	local data = specification
	data.Name = name
	data.DefaultVisuals = data.DefaultVisuals or {}
	if (data.DefaultVisuals.DisplayName == nil) then data.DefaultVisuals.DisplayName = name end
	data.AttributeData = data.AttributeData or {}
	data.ModelType = data.ModelType or "Basic"
	setmetatable(data, BaseGateUtils)
	
	Specifications[name] = data
end

-- ----------------------------- ------- GATE INSTANCE DEFINITIONS ------- ----------------------------

-- Id of the last instantiated gate
local currentID: TGateID = 0

function GateService.GetGateInstance(gateID: TGateID): TGateInstance?
	return Instances[gateID]
end

-- ALL THIS IS BULLSHIT -- ALL THIS IS BULLSHIT -- ALL THIS IS BULLSHIT -- ALL THIS IS BULLSHIT -- ALL THIS IS BULLSHIT --
-- local gatesFolder = Workspace:FindFirstChild("Gates")
-- if not gatesFolder then
-- 	gatesFolder = Instance.new("Folder")
-- 	gatesFolder.Name = "Gates"
-- 	gatesFolder.Parent = Workspace
-- end

-- local playerFolders = setmetatable({}, { __mode = "kv"} )
-- local function getPlayerFolder(owner: TPlayerID)
-- 	local folderName = if owner == 0 then "Server" else tostring(owner)
-- 	if playerFolders[folderName] then return playerFolders[folderName]
-- 	else 
-- 		local ownerFolder = gatesFolder:FindFirstChild(folderName)
-- 		if ownerFolder and ownerFolder:IsA("Folder") then
-- 			playerFolders[folderName] = ownerFolder
-- 			return ownerFolder
-- 		else
-- 			local newFolder = Instance.new("Folder")
-- 			newFolder.Name = folderName
-- 			newFolder.Parent = gatesFolder
-- 			playerFolders[folderName] = ownerFolder
-- 			return newFolder
-- 		end
-- 	end
-- end

-- local function getSpecificationForGate(gate: TGateInstance): TSpecification
-- 	local specification = Specifications[gate.Name]
-- 	assert(specification, "Gate specification '" .. tostring(gate.Name) .. "' is not registered")
-- 	return specification
-- end

-- local function getRelativePath(root: Instance, descendant: Instance): { string }?
-- 	local path = {}
-- 	local current: Instance? = descendant

-- 	while current and current ~= root do
-- 		table.insert(path, 1, current.Name)
-- 		current = current.Parent
-- 	end

-- 	if current ~= root then
-- 		return nil
-- 	end

-- 	return path
-- end

-- local function findByPath(root: Instance, path: { string }): Instance?
-- 	local current: Instance? = root
-- 	for _, name in ipairs(path) do
-- 		current = current and current:FindFirstChild(name)
-- 		if current == nil then
-- 			return nil
-- 		end
-- 	end
-- 	return current
-- end

-- local function remapModelReferences(gate: TGateInstance, oldModel: Model, newModel: Model)
-- 	for key, value in pairs(gate) do
-- 		if typeof(value) ~= "Instance" then
-- 			continue
-- 		end

-- 		if value == oldModel then
-- 			gate[key] = newModel
-- 		elseif value:IsA("ClickDetector") and value:IsDescendantOf(oldModel) then
-- 			value.Parent = newModel
-- 		elseif value:IsDescendantOf(oldModel) then
-- 			local path = getRelativePath(oldModel, value)
-- 			if path ~= nil then
-- 				local replacement = findByPath(newModel, path)
-- 				if replacement ~= nil then
-- 					gate[key] = replacement
-- 				end
-- 			end
-- 		end
-- 	end
-- end

-- function GateService.GetVisualEditorData(gateID: TGateID)
-- 	local gate = Instances[gateID]
-- 	assert(gate, "Gate " .. gateID .. " does not exist")

-- 	local specification = getSpecificationForGate(gate)
-- 	local visuals = Visuals.CompleteWithDefaults(
-- 		Visuals.Clone(gate.Visuals or {}),
-- 		specification.Name,
-- 		#specification.Nodes.Inputs,
-- 		#specification.Nodes.Outputs,
-- 		specification.DefaultVisuals
-- 	)

-- 	local main = gate.Model.Decoration.Main
-- 	local hasDisplayName = main:FindFirstChild("DisplayNameGui", true) ~= nil

-- 	return {
-- 		SpecificationName = specification.Name,
-- 		HasDisplayName = hasDisplayName,
-- 		InputNodes = table.clone(specification.Nodes.Inputs),
-- 		OutputNodes = table.clone(specification.Nodes.Outputs),
-- 		Visuals = visuals,
-- 	}
-- end
-- ALL THIS WAS BULLSHIT -- ALL THIS WAS BULLSHIT -- ALL THIS WAS BULLSHIT -- ALL THIS WAS BULLSHIT -- ALL THIS WAS BULLSHIT --

function GateService.Instantiate(owner: TPlayerID, specificationName: TSpecificationName, cframe: CFrame, extras: { Style: Models.TStyleType?, Visuals: Models.TVisuals?, Attributes: TAttribute? }? ): TGateID
	-- print("Instantiating gate. Specification: " .. specificationName .. ", ID: " .. currentID .. ", Owner: ".. owner .. ", CFrame: ", tostring(cframe))
	currentID = currentID + 1
	
	-- Initializes the initial data
	local specification = Specifications[specificationName]
	assert(specification, "Can't instantiate gate of specification \"" .. specificationName .. "\". Reason: Specification has not been registered.")
	
	-- Loads extras
	extras = extras or {}; assert(extras ~= nil, "Can't instantiate gate. Reason: Extras table was nil (Unreachable code).")
	
	local styleName = extras.Style or "Classic"
	local styleDefaultVisuals = Models.GetStyleDefaults(styleName, { Input = #specification.Nodes.Inputs, Output = #specification.Nodes.Outputs })
	
	local visuals = extras.Visuals or {}
	setmetatable(visuals, { __index = function(_, key)
		local specificationValue = specification.DefaultVisuals[key]
		return if specificationValue ~= nil
			then specificationValue
			else styleDefaultVisuals[key]
	end})
	
	local attributes = extras.Attributes or {}
	
	-- Loads the model
	local model = Models.Instantiate(specification.ModelType, specification.Nodes, styleName, visuals)
		model.Instance:PivotTo(cframe)
		model.Instance:SetAttribute("GateId", currentID)
		model.Instance.Name = specificationName
		model.Instance.Parent = if owner == -1 then Workspace.Gates.Server else Workspace.Gates[owner] -- TODO: This can go wrong. Change this.
	
	-- Creates the gate entry
	local gate = {
		Id = currentID,
		OwnerId = owner,
		Model = model,
		Visuals = visuals,
		Attributes = {},
		Signals = {}
	}
	
	-- Initializes with data
	for _, output in ipairs(specification.Nodes.Outputs) do
		gate.Signals[output] = false
	end
	
	for name, attributeSpecification in pairs(specification.AttributeData) do
		gate.Attributes[name] = Attributes.GetOrDefault(attributes[name], attributeSpecification)
	end
	
	setmetatable(gate, { __index = specification } )
	
	-- Registers the instance
	Instances[currentID] = gate
	
	if specification.Setup then specification.Setup(gate) end
	Updates.Propagate(currentID)
	
	return currentID
end

-- ALL THIS IS BULLSHIT -- ALL THIS IS BULLSHIT -- ALL THIS IS BULLSHIT -- ALL THIS IS BULLSHIT -- ALL THIS IS BULLSHIT --
-- function GateService.ApplyVisuals(gateID: TGateID, nextVisuals: any)
-- 	local gate = Instances[gateID]
-- 	assert(gate, "Gate " .. gateID .. " does not exist")

-- 	local specification = getSpecificationForGate(gate)
-- 	local visuals = Visuals.CompleteWithDefaults(
-- 		Visuals.Clone(nextVisuals or {}),
-- 		specification.Name,
-- 		#specification.Nodes.Inputs,
-- 		#specification.Nodes.Outputs,
-- 		specification.DefaultVisuals
-- 	)

-- 	local oldModel = gate.Model
-- 	local newModel: Model = Models.new(specification.Nodes, visuals)
-- 	newModel:PivotTo(oldModel:GetPivot())
-- 	newModel:SetAttribute("GateId", gateID)
-- 	newModel.Name = specification.Name
-- 	newModel.Parent = oldModel.Parent

-- 	gate.Model = newModel
-- 	gate.Visuals = visuals

-- 	remapModelReferences(gate, oldModel, newModel)
-- 	Connections.RebindGate(gateID, newModel :: any)

-- 	oldModel:Destroy()
-- 	Updates.Propagate(gateID)

-- 	return Visuals.Clone(visuals)
-- end
-- ALL THIS WAS BULLSHIT -- ALL THIS WAS BULLSHIT -- ALL THIS WAS BULLSHIT -- ALL THIS WAS BULLSHIT -- ALL THIS WAS BULLSHIT --

function GateService.Update(gateID: TGateID, payload)
	assert(Instances[gateID], "Can't interact with gate " .. gateID .. ". Reason: Gate is not a currently registered instance.")
	
	Updates.Propagate(gateID, payload)
end

function GateService.Move(gateID: TGateID, to: CFrame)
	assert(Instances[gateID], "Can't move gate " .. gateID .. ". Reason: Gate is not a currently registered instance.")
	local gate = Instances[gateID]
	
	gate.Model:PivotTo(to)
	
	-- Move all in connections
	for _, inputName in ipairs(gate.Nodes.Inputs) do
		for _, wire in ipairs(Connections.GetIncoming(gateID, inputName)) do
			Connections.UpdateCFrame(wire)
		end
	end
	
	-- Move all out connections
	for _, outputName in ipairs(gate.Nodes.Outputs) do
		for _, wire in ipairs(Connections.GetOutgoing(gateID, outputName)) do
			Connections.UpdateCFrame(wire)
		end
	end
end

function GateService.Connect(fromID: TGateID, toID: TGateID, fromNode: TNodeName, toNode: TNodeName )
	local fromGate = Instances[fromID]
	assert(fromGate, "Can't make connection from gate " .. fromID .. ". Reason: Gate is not a currently registered instance.")
	assert(table.find(fromGate.Nodes, fromNode), "Can't make connection from gate " .. fromID .. ", output \"" .. fromNode .. "\". Reason: Gate has no such output node.")
	
	local toGate = Instances[toID]
	assert(toGate, "Can't make connection to gate " .. toID .. ". Reason: Gate is not a currently registered instance.")
	assert(table.find(toGate.Nodes, toNode), "Can't make connection to gate " .. toID .. ", input \"" .. toNode .. "\". Reason: Gate has no such input node.")
	
	assert(not Connections.AreConnected(fromID, toID, fromNode, toNode), "Can't make connection from gate " ..  fromID .. ", output \"" .. fromNode .. "\" to gate " .. toID .. ", input \"" .. toNode .. "\". Reason: Connection already exists.")
	
	-- Register the connection
	local wire = Connections.new(fromID, toID, fromGate.Model.Nodes[fromNode], toGate.Model.Nodes[toNode])
	
	Updates.RegisterVisualChange(wire, { Color = ColorSequence.new(if Signals.toBoolean(fromGate.Nodes.Signals[fromNode]) then Color3.new(0.9, 0.9, 1) else Color3.new(0, 0, 0.1)) })
	Updates.Propagate(toID)
end

function GateService.Disconnect(fromID: TGateID, toID: TGateID, fromNode: TNodeName, toNode: TNodeName )
	local fromGate = Instances[fromID]
	assert(fromGate, "Can't destroy connection from gate " .. fromID .. ". Reason: Gate is not a currently registered instance.")
	assert(table.find(fromGate.Nodes, fromNode), "Can't destroy connection from gate " .. fromID .. ", output \"" .. fromNode .. "\". Reason: Gate has no such output node.")
	
	local toGate = Instances[toID]
	assert(toGate, "Can't destroy connection to gate " .. toID .. ". Reason: Gate is not a currently registered instance.")
	assert(table.find(toGate.Nodes, toNode), "Can't destroy connection to gate " .. toID .. ", input \"" .. toNode .. "\". Reason: Gate has no such input node.")
	
	assert(Connections.AreConnected(fromID, toID, fromNode, toNode), "Can't destroy connection from gate " ..  fromID .. ", output \"" .. fromNode .. "\" to gate " .. toID .. ", input \"" .. toNode .. "\". Reason: Connection is not registered.")
	
	Connections.Disconnect(fromID, toID, fromNode, toNode)
	-- fromNode[toID][Nodes.to] = nil
	-- toNode[fromID][Nodes.from] = nil
	-- if next(fromNode[toID]) == nil then fromNode[toID] = nil end
	-- if next(toNode[fromID]) == nil then toNode[fromID] = nil end

	-- local wires = Connections.GetOutgoing(fromID, Nodes.from)
	-- for i = #wires, 1, -1 do
	-- 	local wire = wires[i]
	-- 	local matches = wire:GetAttribute("ToGate") == toID and wire:GetAttribute("ToNode") == Nodes.to
	-- 	if matches then
	-- 		Connections.Destroy(wire)
	-- 	end
	-- end

	Updates.Propagate(toID)
end

function GateService.Destroy(gateID: TGateID)
	local gate = Instances[gateID]
	assert(gate, "Can't destroy gate " .. gateID .. ". Reason: Gate is not a currently registered instance.")
	
	Updates.CancelAllWakeups(gateID)
	
	-- Disconnect all in connections
	for _, inputName in ipairs(gate.Nodes.Inputs) do
		for _, wire in ipairs(Connections.GetIncoming(gateID, inputName)) do
			GateService.Disconnect(wire:GetAttribute("FromGate"), gateID, wire:GetAttribute("FromNode"), wire:GetAttribute("ToNode"))
		end
	end
	
	-- Disconnect all out connections
	for _, outputName in ipairs(gate.Nodes.Outputs) do
		for _, wire in ipairs(Connections.GetOutgoing(gateID, outputName)) do
			GateService.Disconnect(gateID, wire:GetAttribute("ToGate"), wire:GetAttribute("FromNode"), wire:GetAttribute("ToNode"))
		end
	end
	
	Models.Destroy(gate.Model)
	
	Instances[gateID] = nil
end

function GateService.ReadAttributeFromNode(gateID: TGateID, attributeName: TAttributeName, targetNode: TNodeName)
	local gate = Instances[gateID]
	assert(gate, "Can't read attribute from input from gate " .. gateID .. ". Reason: Gate is not a currently registered instance.")
	assert(targetNode, "Can't read attribute from input from gate " .. gateID .. ", input \"" .. targetNode .. "\". Reason: Gate has no such input node.")
	
	local attribute = gate.Attributes[attributeName]
	assert(attribute ~= nil, "Can't read attribute \"" .. attributeName .. "\" from input from gate " .. gateID .. ". Reason: Gate has no such attribute.")
	
	return if next(Connections.GetIncoming(gateID, targetNode)) == nil
		then attribute
		else gate:ReadInput(targetNode)
end

function GateService.ReadInput(gateID: TGateID, targetNode: TNodeName)
	assert(Instances[gateID], "Can't read input from gate " .. gateID .. ". Reason: Gate is not a currently registered instance.")
	assert(targetNode, "Can't read input from gate " .. gateID .. ", input \"" .. targetNode .. "\". Reason: Gate has no such input node.")
	
	local signals = {}
	for _, wire in ipairs(Connections.GetIncoming(gateID, targetNode)) do
		local fromGateID = wire:GetAttribute("FromGate")
		local fromNode = wire:GetAttribute("FromNode")
		assert(Instances[fromGateID], "Can't read output from gate " .. fromGateID .. ". Reason: Gate is not a currently registered instance.")
		assert(fromNode, "Can't read output from gate " .. gateID .. ", output \"" .. fromNode .. "\". Reason: Gate has no such input node.")
		assert(Connections.AreConnected(fromGateID, gateID, fromNode, targetNode), "Can't read output from gate " .. fromGateID .. ", output \"" .. fromNode .. "\" when reading gate " .. gateID .. ", input \"" .. targetNode .. "\". Reason: Connection is not registered.")
		
		table.insert(signals, Instances[fromGateID].Signals[fromNode])
	end
	local raw = Signals.Collapse(signals)
	
	return {
		Raw = raw,
		AsString  = function() return Signals.toString(raw)  end,
		AsNumber  = function() return Signals.toNumber(raw)  end,
		AsBoolean = function() return Signals.toBoolean(raw) end
	}
end

function GateService.SetAttributeOrDefault(gateID: TGateID, attributeName: string, value: string | number | boolean)
	local gate = Instances[gateID]
	assert(gate, "Can't set attribute of gate " .. gateID .. ". Reason: Gate is not a currently registered instance.")
	assert(gate.Attributes[attributeName] ~= nil, "Can't set attribute \"" .. attributeName .. "\" of gate " .. gateID .. ". Reason: Gate has no such attribute.")
	
	gate.Attributes[attributeName] = Attributes.GetOrDefault(value, gate.AttributeData[attributeName])
	Updates.Propagate(gateID)
end

-- ----------------------------- -------- INITIALIZE SUBMODULES ---------- -----------------------------

-- TODO: Remove this crap
-- LoadSpecifications()
Updates.Initialize(Instances)

-- ----------------------------- ------------ END OF MODULE -------------- -----------------------------

return GateService
