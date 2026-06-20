--[[ SUPPLIES TOOL
		Point to a gate to copy it, click again to place it.
		Copied gates store visual data and attribute data, but not permission data.
]]

-- Requires and services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local LocalServices = StarterPlayerScripts.Services

local PointerService = require(LocalServices.PointerService)
local MessageService = require(LocalServices.MessageService)
local GateVisuals = require(ReplicatedStorage.Gates.GateVisuals)
local BuildMode = require(StarterPlayerScripts.Tool.BuildMode)

-- Events
-- local Query = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Queries"):WaitForChild("Query")
-- local SpawnEvent = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Queries"):WaitForChild("Spawn")

-- References
local Terrain = workspace:WaitForChild("Terrain")
local Tool = script.Parent

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
	
	-- local result, error = Query:InvokeServer(gate:GetAttribute("Id"), "Spawn")
	-- if not result then return MessageService.SendMessage(error :: string) end
	
	BuildMode.Activate(gate:Clone())
end

local function Deactivate()
	local gateGhost = BuildMode.Deactivate()
	if not gateGhost then return end
	
	local context = DeactivationContext()
	-- if context == "Valid" then
	--	SpawnEvent:InvokeServer(gate:GetAttribute("Id"), gate:GetPivot(), visuals)
	-- end	
	
	gateGhost:Destroy()
end

-- ----------------------------- --------- TOOL CALLBACKS --------- -------------------------------

Tool.Activated:Connect(function() if BuildMode.active then Deactivate() else Activate() end end)
Tool.Unequipped:Connect(Deactivate)
