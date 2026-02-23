--!strict
--[[ POINTER SERVICE
		Handles hover, click, and pointer movement.
		Also exposes events for when the pointer enters or leaves a gate or node.
		
		Should be working for mobile. I will make a console cursor later.
]]

-- Requires and Services
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace		     = game:GetService("Workspace")

-- References
local player = Players.LocalPlayer :: Player
local camera = Workspace.CurrentCamera :: Camera

-- Filter
local raycastFilter = Instance.new("Folder")
raycastFilter.Name = "RaycastFilter"
raycastFilter.Parent = Workspace

-- Raycast
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { raycastFilter, Workspace:WaitForChild("Characters") }

local MAX_RAY_DISTANCE = 1000

-- Events
local hoverChanged = Instance.new("BindableEvent")
local gateHovered  = Instance.new("BindableEvent")
local nodeHovered  = Instance.new("BindableEvent")
local interacted   = Instance.new("BindableEvent")

-- State
local running  = false
local renderConnection: RBXScriptConnection? = nil

local lastPointerPos: Vector3? = nil
local currentResult: RaycastResult? = nil

-- Debugging
local logger = require(game:GetService("ReplicatedStorage").LoggerService)
local log = logger.new("PointerService")

local DEBUG_BALL = false -- toggle debug visualization

local debugBall: Part?
if DEBUG_BALL then
	debugBall = Instance.new("Part")
	debugBall.Shape = Enum.PartType.Ball
	debugBall.Size = Vector3.new(0.3, 0.3, 0.3) -- adjust size
	debugBall.Anchored = true
	debugBall.CanCollide = false
	debugBall.Material = Enum.Material.Neon
	debugBall.Color = Color3.fromRGB(0, 255, 0) -- bright green
	debugBall.Transparency = 0.5
	debugBall.Parent = raycastFilter

	-- Ignore raycasts for the ball
	table.insert(rayParams.FilterDescendantsInstances, debugBall)
end

-- ----------------------------- ------- RECORD DEFINITION -------- ---------------------------

local PointerService = {
	RaycastFilter = raycastFilter,
	
	HoveredInstance = nil :: Instance?,
	HoveredGate = nil :: Model?,
	HoveredNode = nil :: BasePart?,
	HitPosition = nil :: Vector3?,
	
	OnHoverChanged = hoverChanged.Event,
	OnGateHovered  = gateHovered.Event,
	OnNodeHovered  = nodeHovered.Event,
	OnInteraction  = interacted.Event,
}

-- ----------------------------- -------- HELPER METHODS --------- ---------------------------

local function isGate(model: Model?): boolean
	-- Check gate models (assume node structure: Model -> BaseGate & (Nodes -> Input1 & Input2 & ... & InputN) & Decoration -> Main)
	if not model then return false end
	return model:FindFirstChild("Decoration") ~= nil
		and model:FindFirstChild("Base") ~= nil
		and model:FindFirstChild("Nodes") ~= nil
end

local function findGateFromInstance(instance: Instance?): Model?
	if not instance then return nil end
	
	local model = instance:FindFirstAncestorWhichIsA("Model")
	return if isGate(model) then model else nil
end

local function findClosestNodeFromGate(gate: Model?, hitPos: Vector3?): BasePart?
	if not gate or not isGate(gate) or not hitPos then return nil end
	
	local nodes = gate:FindFirstChild("Nodes")
	if not nodes then return nil end
	
	local closest, dist = nil, math.huge
	for _, node in nodes:GetChildren() do
		if not node:IsA("BasePart") then continue end
		if not node:GetAttribute("Type") then continue end

		local d = (hitPos - node.Position).Magnitude
		if d < dist then
			closest, dist = node, d
		end
	end

	return closest
end

-- ----------------------------- -------- UPDATE RAYCAST --------- ------------------------------

local function updateRaycast()
	if not lastPointerPos or not running then return end
	
	local ray = camera:ScreenPointToRay(lastPointerPos.X, lastPointerPos.Y)
	currentResult = Workspace:Raycast(ray.Origin, ray.Direction * MAX_RAY_DISTANCE, rayParams)
	
	local instance = (currentResult and currentResult.Instance) or nil
	local hitPos = (currentResult and currentResult.Position) or nil
	
	PointerService.HitPosition = hitPos
	
	-- Move debug ball to hit position
	if DEBUG_BALL and debugBall then
		if currentResult and currentResult.Position then
			debugBall.Position = currentResult.Position
			debugBall.Transparency = 0.5
		else
			-- Hide it when nothing is hit
			debugBall.Transparency = 1
		end
	end

	-- If part changed
	if instance ~= PointerService.HoveredInstance then
		log.info("Pointing to " .. tostring(PointerService.HitPosition or "nothing"))
		PointerService.HoveredInstance = instance
		
		local gate = findGateFromInstance(instance)
		local node = findClosestNodeFromGate(gate, hitPos)
		
		if gate ~= PointerService.HoveredGate then
			PointerService.HoveredGate = gate
			log.info("Changed hovered gate to: " .. (gate and gate.Name or "nil"))
			if gate then gateHovered:Fire(gate) end
		end
		
		if node ~= PointerService.HoveredNode then
			PointerService.HoveredNode = node
			log.info("Changed hovered node to: " .. (node and node.Name or "nil"))
			if node then nodeHovered:Fire(node) end
		end
		
		hoverChanged:Fire(instance, gate, node)
		return
	end
	
	-- If position changed, check for closest node change
	if PointerService.HoveredGate then
		local node = findClosestNodeFromGate(PointerService.HoveredGate, hitPos)
		if node ~= PointerService.HoveredNode then
			PointerService.HoveredNode = node
			log.info("Changed hovered node to: " .. (node and node.Name or "nil"))
			if node then nodeHovered:Fire(node) end
		end
	end
	
end
	
-- ----------------------------- -------- INPUT HANDLING --------- ---------------------------

UserInputService.InputChanged:Connect(function(input) 
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		lastPointerPos = input.Position
	elseif input.UserInputType == Enum.UserInputType.Touch then
		lastPointerPos = input.Position
	end
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		interacted:Fire(
			PointerService.HoveredInstance,
			PointerService.HoveredGate,
			PointerService.HoveredNode
		)
	end
end)

-- ----------------------------- ---------- LIFECYCLE  ----------- -------------------------------

function PointerService.Start()
	if running then return end
	running = true
	
	renderConnection = RunService.RenderStepped:Connect(updateRaycast)
end

function PointerService.Stop()
	if not running then return end
	running = false
	
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

PointerService.Start()

-- ----------------------------- --------- END OF MODULE ---------- -------------------------------

return PointerService
