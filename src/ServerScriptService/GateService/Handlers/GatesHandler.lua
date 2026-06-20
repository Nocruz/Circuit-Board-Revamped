--[[ GATES HANDLER
		Module that holds all Gate instances and current state.
]]

-- Map of ID -> Gate
local instances = {}

-- ----------------------------- ----------- MODULE DEFINITION ----------- -----------------------------

local GatesHandler = {}

function GatesHandler.Add(id: number, gate)
	instances[id] = gate
end

function GatesHandler.Debug()
	print("Debugging gate instances:")
	for id, gate in pairs(instances) do
		print("ID: " .. gate.ID)
		print("\tOwnerID: " .. gate.OwnerID)
		print("\tSpecification: " .. gate.Specification.Name)
		print("\tAttributes:")
		for name, value in pairs(gate.Attributes) do
			print("\t\tName: \"" .. name .. "\", Value: " .. value)
		end
		print("\tNodes:")
		print("\tInputs:")
		for name, connections in pairs(gate.Nodes.Inputs) do
			print("\t\tName: \"" .. name .. "\"")
		end
		print("\tOutputs:")
		for name, connections in pairs(gate.Nodes.Outputs) do
			print("\t\tName: \"" .. name .. "\", Signal: ", gate.Nodes.Signals[name])
		end
	end
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return GatesHandler
