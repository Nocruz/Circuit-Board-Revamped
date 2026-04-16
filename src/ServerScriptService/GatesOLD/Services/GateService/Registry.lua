--!strict
--[[ GATE SERVICE REGISTRY
		Handles specification and gate lookup tables.
]]

local Registry = {}

--- Specifications

-- ----------------------------- -------- SPECIFICATIONS --------------- -----------------------------

function Registry.RegisterSpecification(state: any, name: string, specification: any)
	assert(type(name) == "string" and name ~= "", "Gate specification name must be a non-empty string")
	assert(specification ~= nil, "Gate specification '" .. name .. "' is nil")
	assert(specification.Name == name, "Gate specification name mismatch for '" .. name .. "'")
	assert(state.Specifications[name] == nil, "Gate specification '" .. name .. "' is already registered")

	state.Specifications[name] = specification
end

function Registry.GetSpecification(state: any, name: string): any
	return state.Specifications[name]
end

--- Gates

-- ----------------------------- -------------- GATES ------------------ -----------------------------

function Registry.GetById(state: any, id: number): any
	return state.GatesById[id]
end

function Registry.GetByModel(state: any, modelOrInstance: Instance): any
	if modelOrInstance:IsA("Model") then
		return state.GatesByModel[modelOrInstance]
	end

	local model = modelOrInstance:FindFirstAncestorWhichIsA("Model")
	while model ~= nil do
		local gate = state.GatesByModel[model]
		if gate ~= nil then
			return gate
		end

		model = model.Parent and model.Parent:FindFirstAncestorWhichIsA("Model") or nil
	end

	return nil
end

function Registry.AddGate(state: any, gate: any)
	state.GatesById[gate.Id] = gate
	state.GatesByModel[gate.Model] = gate
end

function Registry.RemoveGate(state: any, gate: any)
	state.GatesById[gate.Id] = nil
	state.GatesByModel[gate.Model] = nil
end

return Registry
