--!strict
--[[ GATE SERVICE CLIPBOARD
		Saving and restoring selected builds.
]]

local Helpers = require(script.Parent.Helpers)

local Clipboard = {}

local MAX_BUILDS_PER_PLAYER = 24
local MAX_GATES_PER_BUILD = 250
local MAX_WIRES_PER_BUILD = 1000

--- Helpers

-- ----------------------------- ------------ HELPERS ------------------- -----------------------------

local function getPlayerClipboard(state: any, userId: number): { [string]: any }
	state.PlayerBuilds[userId] = state.PlayerBuilds[userId] or {}
	return state.PlayerBuilds[userId]
end

--- Public API

-- ----------------------------- ------------- PUBLIC API ------------- -----------------------------

function Clipboard.ListBuilds(state: any, userId: number): { any }
	local summaries = {}
	for _, build in pairs(getPlayerClipboard(state, userId)) do
		table.insert(summaries, {
			Title = build.Title,
			GateCount = #build.Gates,
			WireCount = #build.Wires,
			UpdatedAt = build.UpdatedAt,
		})
	end

	table.sort(summaries, function(a, b)
		if a.UpdatedAt == b.UpdatedAt then
			return a.Title < b.Title
		end
		return a.UpdatedAt > b.UpdatedAt
	end)

	return summaries
end

function Clipboard.SerializeSelection(state: any, publicApi: any, userId: number, cornerA: Vector3, cornerB: Vector3): (boolean, string?, any?)
	local minBounds, maxBounds = Helpers.NormalizeBounds(cornerA, cornerB)
	local selected = {}

	for _, gate in pairs(state.GatesById) do
		if gate.Destroyed then
			continue
		end

		local pivot = state.GridService.fromCFrame(gate.Model:GetPivot())
		if not Helpers.ContainsPoint(minBounds, maxBounds, pivot.Position) then
			continue
		end
		if not state.PermissionService.canPlayerDo(userId, gate.OwnerId, "Move") then
			continue
		end
		if not state.PermissionService.canPlayerDo(userId, userId, "Spawn", gate.Specification.Name) then
			continue
		end

		table.insert(selected, gate)
	end

	table.sort(selected, function(a, b)
		return a.Id < b.Id
	end)

	if #selected == 0 then
		return false, "No movable gates were inside that selection."
	end
	if #selected > MAX_GATES_PER_BUILD then
		return false, "Selection is too large to save."
	end

	local selectedIndex = {}
	local savedGates = {}
	for index, gate in ipairs(selected) do
		local pivot = state.GridService.fromCFrame(gate.Model:GetPivot())
		selectedIndex[gate] = index
		savedGates[index] = {
			SpecificationName = gate.Specification.Name,
			Visuals = publicApi.CaptureVisuals(gate),
			Attributes = Helpers.CloneAttributeValues(gate.Attributes),
			Offset = pivot.Position - minBounds,
			Rotation = pivot.Rotation,
		}
	end

	local savedWires = {}
	for _, gate in ipairs(selected) do
		if gate.Connections ~= nil then
			for targetGate, inputMap in pairs(gate.Connections) do
				local fromIndex = selectedIndex[gate]
				local toIndex = selectedIndex[targetGate]
				if fromIndex ~= nil and toIndex ~= nil then
					for inputName in pairs(inputMap) do
						table.insert(savedWires, {
							FromIndex = fromIndex,
							ToIndex = toIndex,
							InputName = inputName,
						})
					end
				end
			end
		end
	end

	if #savedWires > MAX_WIRES_PER_BUILD then
		return false, "Selection has too many wires to save."
	end

	return true, nil, {
		Title = "",
		Gates = savedGates,
		Wires = savedWires,
		UpdatedAt = os.time(),
	}
end

function Clipboard.RestoreBuild(state: any, publicApi: any, userId: number, build: any, anchorCFrame: CFrame): (boolean, string?)
	for _, savedGate in ipairs(build.Gates) do
		if state.Specifications[savedGate.SpecificationName] == nil then
			return false, "Missing gate specification '" .. savedGate.SpecificationName .. "'."
		end
		if not state.PermissionService.canPlayerDo(userId, userId, "Spawn", savedGate.SpecificationName) then
			return false, "You cannot restore builds containing '" .. savedGate.SpecificationName .. "'."
		end
	end

	local anchor = state.GridService.fromCFrame(anchorCFrame)
	local restored = {}
	for index, savedGate in ipairs(build.Gates) do
		local cframe = Helpers.RotationToCFrame(anchor.Position + savedGate.Offset, savedGate.Rotation)
		local gate = publicApi.Instantiate(userId, savedGate.SpecificationName, cframe, Helpers.CloneVisuals(savedGate.Visuals))
		for attributeName, value in pairs(savedGate.Attributes) do
			publicApi.SetAttribute(gate, attributeName, value)
		end
		restored[index] = gate
	end

	for _, savedWire in ipairs(build.Wires) do
		local fromGate = restored[savedWire.FromIndex]
		local toGate = restored[savedWire.ToIndex]
		if fromGate ~= nil and toGate ~= nil then
			publicApi.Connect(fromGate, toGate, savedWire.InputName)
		end
	end

	return true, nil
end

function Clipboard.SaveSelection(state: any, publicApi: any, player: Player, rawTitle: string, cornerA: Vector3, cornerB: Vector3): (boolean, string?, { any }?)
	local title = Helpers.NormalizeTitle(rawTitle)
	if title == "" then
		return false, "Give the clipboard entry a title."
	end

	local clipboard = getPlayerClipboard(state, player.UserId)
	if clipboard[title] == nil then
		local buildCount = 0
		for _ in pairs(clipboard) do
			buildCount += 1
		end
		if buildCount >= MAX_BUILDS_PER_PLAYER then
			return false, "Clipboard is full for this server."
		end
	end

	local success, message, build = Clipboard.SerializeSelection(state, publicApi, player.UserId, cornerA, cornerB)
	if not success or build == nil then
		return false, message
	end

	build.Title = title
	build.UpdatedAt = os.time()
	clipboard[title] = build

	return true, nil, Clipboard.ListBuilds(state, player.UserId)
end

function Clipboard.RestoreSelection(state: any, publicApi: any, player: Player, rawTitle: string, anchorCFrame: CFrame): (boolean, string?, { any }?)
	local title = Helpers.NormalizeTitle(rawTitle)
	local build = getPlayerClipboard(state, player.UserId)[title]
	if build == nil then
		return false, "That clipboard entry does not exist."
	end

	local success, message = Clipboard.RestoreBuild(state, publicApi, player.UserId, build, anchorCFrame)
	if not success then
		return false, message
	end

	return true, nil, Clipboard.ListBuilds(state, player.UserId)
end

return Clipboard
