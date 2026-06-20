--[[ GATE CONTROLLER
		Public API to interact with the whole system.
		Handles coordination between submodules.
		Works as a plug-and-play for the game.
]]

-- Requires and Services
local GatesHandler = require(script.GatesHandler)
local SpecificationsHandler = require(script.SpecificationsHandler)

local Models = require(script.Models)

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

-- ----------------------------- ----------- INSTANCE FUNCTIONS ---------- -----------------------------

local nextID = 1

--- Instantiates a new Gate, and returns its ID
--- Assumes all parameters are valid
function GateService.Instantiate(ownerID: number, specificationName: string, cframe: CFrame, visuals, attributes): number
	local specification = SpecificationsHandler.Get(specificationName)
	local solvedVisuals = setmetatable(table.clone(visuals or {}), { __index = specification.DefaultVisuals })
	attributes = attributes or {}
	
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
		gate.Visuals = visuals
		
		gate.Nodes = { Outputs = {}, Inputs = {}, Signals = {} }
		for _, output in ipairs(specification.Nodes.Outputs) do gate.Nodes.Outputs[output] = { }; gate.Nodes.Signals[output] = false end
		for _, input in ipairs(specification.Nodes.Inputs) do gate.Nodes.Inputs[input] = { } end
		
		gate.Attributes = {}
		for name, attributeData in pairs(specification.AttributeData) do gate.Attributes[name] = if attributes[name] ~= nil then attributes[name] else attributeData.Default end
	end
	
	GatesHandler.Add(nextID, gate)
	
	if specification.Setup then specification.Setup(gate) end
	
	nextID = nextID + 1
	return nextID - 1	
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return GateService
