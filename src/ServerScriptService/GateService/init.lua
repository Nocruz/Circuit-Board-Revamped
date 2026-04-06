--[[ GATE SERVICE
]]

-- Requires and services
local Workspace = game:GetService("Workspace")

-- local Connections = require(script.Connections)
-- local Attributes = require(script.Attributes)
-- local Updates = require(script.Updates)
-- local Signals = require(script.Signals)
local Models = require(script.Models)
local Visuals = require(script.Models.Visuals)

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

export type TNodeInstance = { [TGateID]: { TNodeName } }

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
local GateInstances: { [TGateID]: TGateInstance } = {}

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

function GateService.InstantiateGate(owner: TPlayerID, specificationName: TSpecificationName, cframe: CFrame, visuals): TGateInstance
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
	GateInstances[nextID] = gate

	nextID = nextID + 1
	return gate
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return GateService
