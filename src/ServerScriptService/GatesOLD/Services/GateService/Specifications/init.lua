--!strict
--[[ SPECIFICATIONS
		Public specification authoring surface for GateService.
]]

local Types = require(script.Types)
local Factory = require(script.Factory)

local Specifications = {
	Types = Types,
	Factory = Factory,
	Create = Factory.Create,
	new = Factory.Create,
}

--- Helpers

local function getSimpleModules(root: Instance): { ModuleScript }
	local modules = {}

	for _, child in ipairs(root:GetDescendants()) do
		if child:IsA("ModuleScript") and child.Name ~= "init" then
			table.insert(modules, child)
		end
	end

	table.sort(modules, function(left, right)
		return left.Name < right.Name
	end)

	return modules
end

--- Public API

function Specifications.RegisterAll(publicApi: any)
	local simpleFolder = script:FindFirstChild("Simple")
	if simpleFolder == nil then
		return 0
	end

	local registered = 0

	for _, moduleScript in ipairs(getSimpleModules(simpleFolder)) do
		local schema = require(moduleScript)
		local specification = Factory.Create(schema)
		publicApi.RegisterSpecification(specification.Name, specification)
		registered += 1
	end

	return registered
end

return Specifications
