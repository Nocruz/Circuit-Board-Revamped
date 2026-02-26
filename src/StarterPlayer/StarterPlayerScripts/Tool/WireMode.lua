--!strict
--[[ WIRE MODE
		Singleton that handles the "Wiring" state the Wire tool uses
		It is controlled by the Wire.Controller LocalScript,
			and Wire.Visuals / Wire.Connections handle the other stuff.
]]

-- Requires and services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local LocalServices = StarterPlayerScripts.Services

local PointerService = require(LocalServices.PointerService)

-- Debugging
local Logger = require(ReplicatedStorage.Services.LoggerService)
local log = Logger.new("WireMode")

-- Visuals
local PointerBallPrefab: Part = ReplicatedStorage.Client.UI.WireMode.PointerBall
local WirePrefab: Beam = ReplicatedStorage.Wire

-- State
local pointerBall: Part? = nil
local wire: Beam? = nil

local renderConnection: RBXScriptConnection? = nil
local hoverConnection: RBXScriptConnection? = nil

local lastGate: Model? = nil

local WireMode = { active = false }

-- ----------------------------- --------- HELPER METHODS -------- ------------------------------

local function instantiateWire(from: Attachment)
	local pointerBall = pointerBall :: { WireAttachment: Attachment }
	
	log.info("Instantiating wire...")

	wire = WirePrefab:Clone()
	wire.Parent = from
	wire.Attachment0 = from
	wire.Attachment1 = pointerBall.WireAttachment
end

local function disposeWire()
	if not wire then return end

	log.info("Disposing wire")

	wire:Destroy()
	wire = nil
end

local function activateLabels(model: Model)
	local gate = model :: { Nodes: Folder }
	
	log.info("Activating node labels of " .. model.Name)

	for _, node in ipairs(gate.Nodes:GetChildren()) do
		local billboardGui = node:FindFirstChildWhichIsA("BillboardGui")
		if billboardGui then billboardGui.Enabled = true end
	end
end

local function deactivateLabels(model: Model)
	local gate = model :: { Nodes: Folder }

	log.info("Deactivating node labels of " .. model.Name)

	for _, node in ipairs(gate.Nodes:GetChildren()) do
		local billboardGui = node:FindFirstChildWhichIsA("BillboardGui")
		if billboardGui then billboardGui.Enabled = false end
	end
end

-- ----------------------------- ------ ON RENDER STEP EVENT ----- ------------------------------

local function movePointer()
	local hit, node = PointerService.HitPosition, PointerService.HoveredNode
	local pointerBall = pointerBall :: Part

	if node or hit then
		pointerBall.Parent = workspace
		pointerBall.Position = if node then node.Position else (hit :: Vector3)
	else
		pointerBall.Parent = nil
	end
end

-- ----------------------------- ----------- LIFECYCLE ----------- ------------------------------

function WireMode.Start(node: Instance)
	local attachment = node:FindFirstChildWhichIsA("Attachment") :: Attachment
	instantiateWire(attachment)
	
	WireMode.active = true
	
	log.info("Started connection on " .. node.Name)
end

function WireMode.Stop()
	disposeWire()
	
	WireMode.active = false
	
	log.info("Stopped connection")
end

function WireMode.ActivatePointer()
	if pointerBall then pointerBall:Destroy() end
	if renderConnection then renderConnection:Disconnect() end
	if hoverConnection then hoverConnection:Disconnect() end
	
	pointerBall = PointerBallPrefab:Clone()
	renderConnection = game:GetService("RunService").RenderStepped:Connect(movePointer)
	
	hoverConnection = PointerService.OnHoverChanged:Connect(function(_, gate: Model)
		if lastGate and lastGate ~= gate then 
			deactivateLabels(lastGate) 
			lastGate = nil 
		end

		if gate then
			activateLabels(gate)
			lastGate = gate
		end
	end)
	local gate = PointerService.HoveredGate; if gate then activateLabels(gate); lastGate = gate end
	
	log.info("Pointer activated")
end

function WireMode.DeactivatePointer()
	if pointerBall then pointerBall:Destroy(); pointerBall = nil end
	if renderConnection then renderConnection:Disconnect(); renderConnection = nil end
	
	if hoverConnection then hoverConnection:Disconnect(); hoverConnection = nil end
	if lastGate then deactivateLabels(lastGate); lastGate = nil end
	
	log.info("Pointer deactivated")
end

-- ----------------------------- --------- END OF MODULE ---------- -----------------------------

return WireMode
