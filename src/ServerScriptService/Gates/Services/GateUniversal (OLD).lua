--!strict
--[[ GATE UNIVERSAL 
		This is the base gate.
		It is not meant to be instantiated directly,
		  it is used as a base class for other gates.
		Check type definitions for member information.
		
		I highly recommend checking out other Business Models first.
		
		Design rule: Gates should be simple. Let players discover advanced stuff by themselves.
]]

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")
local Models = ServerScriptService.Gates.Models

local AttributeUniversal = require(Models.AttributeUniversal)
local SignalUniversal = require(Models.SignalUniversal)

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- -----------------------------

type Signal = SignalUniversal.Signal
type ConnectionInformation = { Wire: Beam? }

export type Node = {
	Inputs: { [Gate]: true }
}

export type GateModel = Model & {
	Decoration: { Main: Part },
	Nodes: Folder,
	BaseGate: Part
}

export type Gate = {
	Id: number,
	OwnerId: number,
	
	Instance: GateModel,
	
	-- A gate's Class defines all it's behaviour.
	-- A gate's GateConfig defines GateModel related stuff, like its color and node position.
	-- TODO: Instead of fixed string types, make type a table with a similar structure to GateRegistry.GateConfiguration
	GateConfig: string,
	Class: GateClass,

	Output: Signal,

	InputNodes: { [string]: Node }, -- Virtual property! To be overriden by subclasses
	--[[ InputNodes is a table with the following structure:
			NodeName = { Instance, Inputs = { [OutputGate] = true }
	]]

	Connections: { [Gate]: { [Node]: ConnectionInformation } }, -- Table of gates this gate is connected to
	--[[ Connections is a dictionary with the following structure:
			[TargetGate] = { -- This is a reference to the actual TargetGate class instance
				[TargetNode] = { -- This nodes are the actual InputNodes on the TargetGate class instance	
					Wire = Beam Instance
					-- More data if needed
				}
			}
	]]
	
	Attributes: AttributeUniversal.AttributeTable
}

export type GateClass = {
	__index: GateClass,
	
	name: string,
	inputs: { [string]: Vector2 }, -- Stores input names and Offsets
	output: Vector2?, -- Stores output's offset

	new: (id: number, ownerId: number, configName: string, instance: GateModel) -> Gate,
	destroy: (self: Gate) -> (),
	
	-- Static functions
	update: (self: Gate) -> boolean,
	disconnectNode: (self: Gate, target: Gate, node: Node) -> (),
	
	getBooleanInput: (self: Gate, node: Node) -> boolean,
	getNumericInput: (self: Gate, node: Node) -> number,
	getStringInput:  (self: Gate, node: Node) -> string,
	getSignalInput:  (self: Gate, node: Node) -> Signal,
	
	setAttribute: (self: Gate, attributeName: string, value: AttributeUniversal.Attribute) -> (),
	getAttribute: (self: Gate, attributeName: string) -> AttributeUniversal.Attribute,
	setAttributeFromNode: (self: Gate, attributeName: string, node: Node) -> (),
	
	modelToGateModel: (model: Model) -> GateModel?,
	
	-- Polymorphic members
	ValidAttributes: AttributeUniversal.AttributeTypeTable?,
	ProcessInputs: ((self: Gate) -> Signal)?,
}

-- ----------------------------- ----- UNIVERSAL GATE DEFINITION ----- -----------------------------

local GateUniversal = {} :: GateClass
GateUniversal.__index = GateUniversal
GateUniversal.name = "GateUniversal"
GateUniversal.inputs = {}

function GateUniversal.new(id: number, ownerId: number, configName: string, instance: GateModel): Gate
	local self = setmetatable({} :: Gate, GateUniversal)
	
	self.Id = id
	self.OwnerId = ownerId
	self.Instance = instance
	
	self.Class = GateUniversal
	
	self.Output = false
	
	return self
end

function GateUniversal.destroy(self: Gate)
	-- Clean up connections (Out)
	for targetGate, nodes in pairs(self.Connections) do
		for targetNode, _ in pairs(nodes) do
			self.Class.disconnectNode(self, targetGate, targetNode)
		end
	end

	-- Clean up connections (In)
	for nodeName, node in pairs(self.InputNodes) do
		for outputGate, _ in pairs(node.Inputs) do
			outputGate.Class.disconnectNode(outputGate, self, node)
		end
		table.clear(node.Inputs)
	end

	if self.Instance then self.Instance:Destroy() end

	-- Does NOT clean up from the gate manager!
	-- This is the responsibility of the gate manager.
end

-- ----------------------------- ----- CONNECTION RELATED METHODS ----- -----------------------------

function GateUniversal.disconnectNode(self: Gate, target: Gate, node: Node)
	local gateConnections = self.Connections[target]
	if not gateConnections or not gateConnections[node] then return end

	-- Dispose wire
	if gateConnections[node].Wire then 
		(gateConnections[node].Wire :: Beam):Destroy()
		gateConnections[node].Wire = nil
	end

	gateConnections[node] = nil

	-- Disconnect from input node
	node.Inputs[self] = nil
	
	if next(gateConnections) == nil then self.Connections[target] = nil end
end


function GateUniversal.update(self: Gate)
	--TODO: Implement
	if self.Class.ProcessInputs then
		self.Output = self.Class.ProcessInputs(self)
	end
	
	return true
end

-- ----------------------------- ----- HANDLING MULTIPLE SIGNALS ----- -----------------------------

function GateUniversal.getBooleanInput(self: Gate, node: Node): boolean
	for outGate in pairs(node.Inputs) do
		if SignalUniversal.toBoolean(outGate.Output) then return true end
	end
	return false
end

function GateUniversal.getNumericInput(self: Gate, node: Node): number
	if next(node.Inputs) == nil then return 0 end
	local highestValue: number = 0

	for outGate in pairs(node.Inputs) do
		local out = SignalUniversal.toNumber(outGate.Output) :: number
		if math.abs(out) > math.abs(highestValue) then
			highestValue = out
		end
	end

	return highestValue
end

function GateUniversal.getStringInput(self: Gate, node: Node): string
	return SignalUniversal.toString(self.Class.getSignalInput(self, node))
end

function GateUniversal.getSignalInput(self: Gate, node: Node): Signal
	if next(node.Inputs) == nil then return false end
	local highestValue: Signal = false

	for outGate in pairs(node.Inputs) do
		local out = outGate.Output
		
		if type(out) == "string" then
			if type(highestValue) ~= "string" then
				highestValue = out
			elseif #out :: string > #highestValue :: string then
				highestValue = out
			end
		elseif type(out) == "nil" then
			highestValue = out
		else
			if math.abs(SignalUniversal.toNumber(out)) > math.abs(SignalUniversal.toNumber(highestValue)) then
				highestValue = out
			end
		end
	end

	return highestValue	
end

-- ----------------------------- ------------ ATTRIBUTES ------------ -----------------------------

-- No validation is done here, cause thats the GateManager's responsibility
function GateUniversal.setAttribute(self: Gate, attributeName: string, value: AttributeUniversal.Attribute)
	if not self.Class.ValidAttributes or not self.Class.ValidAttributes[attributeName] then
		warn("Attempt to set invalid attribute '" .. attributeName .. "' on gate " .. self.Instance.Name)
		return
	end	
	
	local attributeType = self.Class.ValidAttributes[attributeName]
	self.Attributes[attributeName] = AttributeUniversal.getValid(self.Attributes[attributeName], value, attributeType)
end

function GateUniversal.getAttribute(self: Gate, attributeName: string): AttributeUniversal.Attribute
	return self.Attributes[attributeName]
end

function GateUniversal.setAttributeFromNode(self:Gate, attributeName: string, node: Node)
	if not self.Class.ValidAttributes or not self.Class.ValidAttributes[attributeName] then
		warn("Attempt to set invalid attribute '" .. attributeName .. "' on gate " .. self.Instance.Name)
		return
	end	
	
	local attributeType = self.Class.ValidAttributes[attributeName]
	if not next(node.Inputs) then self.Attributes[attributeName] = attributeType.Default return end
	
	local value
	if attributeType.Type == "string" then
		value = self.Class.getStringInput(self, node)
	elseif attributeType.Type == "number" then
		value = self.Class.getNumericInput(self, node)
	elseif attributeType.Type == "boolean" then
		value = self.Class.getBooleanInput(self, node)
	end
	
	if value then self.Attributes[attributeName] = AttributeUniversal.getValid(self.Attributes[attributeName], value, attributeType) end
end

-- ----------------------------- ----------- API HELPERS ----------- -----------------------------

function GateUniversal.modelToGateModel(model: Model): GateModel?
	if not model:FindFirstChild("Decoration") or not model:FindFirstChild("Decoration"):FindFirstChild("Main") then return nil end
	if not model:FindFirstChild("Nodes") then return nil end
	if not model:FindFirstChild("BaseGate") then return nil end
	
	return model :: GateModel
end

-- ----------------------------- ----------- END OF MODULE ------------ -----------------------------

return GateUniversal