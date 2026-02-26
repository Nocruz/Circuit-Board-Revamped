--!strict
--[[ FACTORY
		This mass produces gate classes from a schema.
		This is useful cause most classes are extremely simple in logic,
		  and 60 lines of boilerplate code for 60+ gates is an eyesore.
]]

-- Requires and Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AttributeService = require(ServerScriptService.Gates.Services.AttributeService)

local GateClass = require(ServerScriptService.Gates.Definitions.GateClass)
local Types = require(ServerScriptService.Gates.Definitions.Types)

-- References
local Visuals = ReplicatedStorage.Gates.Visuals

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- -----------------------------

export type TGate = Types.TGate
export type TGateClass = Types.TGateClass
export type TGateVisuals = Types.TGateVisuals
export type TSignal = Types.TSignal

export type TGateSchema = {
	name: string,
	inputs: { string },
	hasOutput: boolean?,
	Update: (gate: TGate, origin: "Signal" | "Schedule") -> TSignal,
	Attributes: AttributeService.TAttributeTypeTable?,
	
	Color: Color3?,
	Material: Enum.Material?,
	DisplayName: string?,
	InputOffsets: { [string]: Vector3 }?,
}

-- ----------------------------- ------- GATE FACTORY DEFINITION ------- -----------------------------

local Factory = {}

function Factory.create(schema: TGateSchema): TGateClass
	local newClass = {} :: TGateClass
	newClass.__index = newClass
	setmetatable(newClass, GateClass)
	
	-- Set properties
	newClass.name = schema.name
	newClass.inputs = schema.inputs
	if schema.hasOutput then
		newClass.output = "Output"
	else
		newClass.output = nil
	end
	
	newClass.Update = schema.Update
	
	newClass.validAttributes = schema.Attributes
	
	if schema.Color or schema.Material or schema.DisplayName or schema.InputOffsets then
		local GateVisualConfiguration: Configuration = Instance.new("Configuration")
		GateVisualConfiguration.Name = schema.name
		GateVisualConfiguration.Parent = Visuals
		
		if schema.Color then
			local Color: Color3Value = Instance.new("Color3Value")
			Color.Name = "MainColor"
			Color.Value = schema.Color
			Color.Parent = GateVisualConfiguration
		end
		
		if schema.Material then
			local Material: StringValue = Instance.new("StringValue")
			Material.Name = "MainMaterial"
			Material.Value = schema.Material.Name
			Material.Parent = GateVisualConfiguration
		end
		
		if schema.DisplayName then
			local DisplayName: StringValue = Instance.new("StringValue")
			DisplayName.Name = "DisplayName"
			DisplayName.Value = schema.DisplayName
			DisplayName.Parent = GateVisualConfiguration
		end
		
		if schema.InputOffsets then
			local InputOffsets: Configuration = Instance.new("Configuration")
			InputOffsets.Name = "InputOffsets"
			for inputName, offset in pairs(schema.InputOffsets) do
				local InputOffset: Vector3Value = Instance.new("Vector3Value")
				InputOffset.Name = inputName
				InputOffset.Value = offset
				InputOffset.Parent = InputOffsets
			end
			InputOffsets.Parent = GateVisualConfiguration
		end
	end

	function newClass.new(id: number, ownerId: number, gateModel: Types.TGateModel): TGate
		local gate = setmetatable(GateClass.CreateGate(id, ownerId, gateModel), newClass)
		
		gate.Class = newClass
		
		-- Set nodes
		if #newClass.inputs > 0 then
			gate.Inputs = {} 
			for _, inputName in pairs(newClass.inputs) do gate.Inputs[inputName] = {} end
		end
		if schema.hasOutput then 
			gate.Output = false 
			gate.Connections = {}
		end
		
		if schema.Attributes then
			gate.Attributes = {}
			for attributeName, attribute in pairs(schema.Attributes) do gate.Attributes[attributeName] = attribute.Default end
		end
		
		return gate
	end

	return newClass
end

-- ----------------------------- ----------- END OF MODULE ------------ -----------------------------

return Factory
