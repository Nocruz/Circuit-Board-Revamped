--[[ SPECIFICATIONS HANDLER
		Module that holds all Gate Specifications.
]]

-- Map of name -> Specification
local specifications = {}

-- ----------------------------- ----------- MODULE DEFINITION ----------- -----------------------------

local SpecificationsHandler = {}

function SpecificationsHandler.Add(specification)
	specifications[specification.Name] = specification
end

function SpecificationsHandler.Get(name)
	return specifications[name]
end

function SpecificationsHandler.Debug()
	print("Debugging gate specifications:")
	for name, specification in pairs(specifications) do
		print("Name: " .. specification.Name)
		print("\tNodes:")
		print("\tInputs:")
		for index, nodeName in pairs(specification.Nodes.Inputs) do
			print("\t\tIndex: " .. index .. ", Name: \"" .. nodeName .. "\"")
		end
		print("\tOutputs:")
		for index, nodeName in pairs(specification.Nodes.Outputs) do
			print("\t\tIndex: " .. index .. ", Name: \"" .. nodeName .. "\"")
		end
		print("\tAttributeData:")
		for attributeName, data in pairs(specification.AttributeData) do
			print("\t\tName: \"" .. attributeName .. "\", { Default: " .. data.Default .. ", Predicate count: " .. #data.Predicates .. ", Allowed Values: " .. if data.AllowedValues == nil then "Not specified" elseif #data.AllowedValues == 0 then "None" else table.concat(data.AllowedValues, ","))
		end
		print("\tDefaultVisuals:")
		for key, value in pairs(specification.DefaultVisuals) do
			print("\t\tKey: \"" .. key .. "\", Value: \"" .. tostring(value) .. "\"" )
		end
		print("\t\tInputOffsets: " .. tostring(table.unpack(specification.DefaultVisuals.InputOffsets) or "Does not apply"))
		print("\t\tOutputOffsets: " .. tostring(table.unpack(specification.DefaultVisuals.OutputOffsets) or "Does not apply"))
	end
end
-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return SpecificationsHandler
