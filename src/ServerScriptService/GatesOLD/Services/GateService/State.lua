--!strict
--[[ GATE SERVICE STATE
		Central mutable state shared by GateService child modules.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PermissionService = require(game:GetService("ServerScriptService").Players.PermissionService)
local GridService = require(ReplicatedStorage.Services.GridService)

local State = {}

--- Constructor

-- ----------------------------- ------------- CONSTRUCTOR ------------- -----------------------------

function State.new(): any
	local wiresRoot = Workspace:FindFirstChild("Wires")
	if not (wiresRoot and wiresRoot:IsA("Folder")) then
		local folder = Instance.new("Folder")
		folder.Name = "Wires"
		folder.Parent = Workspace
		wiresRoot = folder
	end

	return {
		Started = false,
		HeartbeatConnection = nil,

		PermissionService = PermissionService,
		GridService = GridService,

		Specifications = {},
		GatesById = {},
		GatesByModel = {},

		NextGateId = 0,
		NextWireId = 0,

		PlayerFolders = {},
		WiresById = {},
		WiresByGate = {},
		WireColourQueue = {},

		PlayerCooldowns = {},
		PlayerBuilds = {},

		TimeWheel = {},
		PendingSchedules = {},
		ImmediateQueue = {},
		DeferredOrder = {},
		DeferredItems = {},
		UpdateCounts = {},
		CurrentTick = nil,
		IsStepping = false,

		GatesRoot = Workspace:WaitForChild("Gates"),
		WiresRoot = wiresRoot,
		Remotes = {},
	}
end

return State
