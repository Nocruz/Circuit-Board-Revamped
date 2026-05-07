--[[ TWEEZERS
		This tool uses BuildMode to
		  request the server to move or destroy a model.
]]

-- Requires and services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local LocalServices = StarterPlayerScripts.Services

local PointerService = require(LocalServices.PointerService)
local MessageService = require(LocalServices.MessageService)
local BuildMode = require(StarterPlayerScripts.Tool.BuildMode)

-- Events
local Query = ReplicatedStorage.Client.Queries.Query
local MoveEvent = ReplicatedStorage.Client.Events.Move
local DestroyEvent = ReplicatedStorage.Client.Events:FindFirstChild("Destroy")

-- References
local Terrain = workspace:WaitForChild("Terrain")
local Tool = script.Parent

-- State
local parent: Instance? = nil
local pivot: CFrame? = nil

-- ----------------------------- ------------- HELPERS ------------ -------------------------------

local function DeactivationContext(): "Skybox" | "Invalid" | "Valid"
	local hit, instance = PointerService.HitPosition, PointerService.HoveredInstance :: Instance
	if not hit then return "Skybox" end
	if instance:IsDescendantOf(Terrain.GateStands) or instance:IsDescendantOf(Terrain.Incinerators) or instance:IsDescendantOf(workspace.Gates.Server) then return "Invalid" end
	return "Valid"
end

-- ----------------------------- ----------- BEHAVIOURS ----------- -------------------------------

local function Activate()
	local gate = PointerService.HoveredGate
	if not gate then return end

	parent, pivot = gate.Parent, gate:GetPivot()
	local result, error = Query:InvokeServer(gate:GetAttribute("GateId"), "Move")
	if not result then
		return MessageService.SendMessage(error :: string)
	end
	
	BuildMode.Activate(gate)
end

local function Deactivate()
	local gate = BuildMode.Deactivate()
	if not gate then return end

	local context = DeactivationContext()
	if context == "Valid" then
		local result, message = MoveEvent:InvokeServer(gate:GetAttribute("GateId"), gate:GetPivot())
		if not result then
			MessageService.SendMessage(message)
			gate:PivotTo(pivot)
		end
		gate.Parent = parent
	elseif context == "Invalid" then
		DestroyEvent:InvokeServer(gate:GetAttribute("GateId"))
	else -- context == "Skybox"
		gate:PivotTo(pivot :: CFrame)
		gate.Parent = parent
	end
	
	parent = nil
	pivot = nil
end

-- ----------------------------- --------- TOOL CALLBACKS --------- -------------------------------

Tool.Activated:Connect(function() if BuildMode.active then Deactivate() else Activate() end end)
Tool.Unequipped:Connect(Deactivate)

-- Enable for drag and drop
Tool.Deactivated:Connect(Deactivate)
