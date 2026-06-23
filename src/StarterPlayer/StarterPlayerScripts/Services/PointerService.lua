--[[ POINTER SERVICE
		Handles all pointer related operations.
		Only supports Mouse for now.
]]

-- Requires and Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local UserInputService = game:GetService("UserInputService")

-- ----------------------------- --------- RAYCAST CONFIGURATION --------- -----------------------------
-- Raycast collision groups
local GROUP_IGNORES = "PointerServiceRaycastIgnore"
local GROUP_RAYCAST = "PointerServiceRaycast"

if not PhysicsService:IsCollisionGroupRegistered(GROUP_IGNORES) or not PhysicsService:IsCollisionGroupRegistered(GROUP_RAYCAST) then
	error("PointerService requires the PhysicsCollisionGroups \"" .. GROUP_IGNORES .. "\" and \"" .. GROUP_RAYCAST .. "\".")
end

local MAX_RAY_DISTANCE = 1000

local rayParams = RaycastParams.new()
rayParams.CollisionGroup = GROUP_RAYCAST
rayParams.IgnoreWater = true

local function ignoreInstance(instance: Instance)
	local function ignore(i: Instance) if i:IsA("BasePart") then i.CollisionGroup = GROUP_IGNORES end end
	ignore(instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		ignore(descendant)
	end
	
	instance.DescendantAdded:Connect(function(descendant)
		ignore(descendant)
	end)
end

local function restoreInstance(instance: Instance)
	local function restore(i: Instance) if i:IsA("BasePart") then i.CollisionGroup = "Default" end end
	restore(instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		restore(descendant)
	end
	
	instance.DescendantAdded:Connect(function(descendant)
		restore(descendant)
	end)
end

-- Ignore characters
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(ignoreInstance)
	if player.Character then
		ignoreInstance(player.Character)
	end
end)

for _, player in Players:GetPlayers() do
	player.CharacterAdded:Connect(ignoreInstance)
	if player.Character then
		ignoreInstance(player.Character)
	end
end

-- Ignore Safezones too
local safezonesFolder = Workspace:WaitForChild("Safezones")
assert(safezonesFolder ~= nil, "No safezones! Forgot to update this script?")
ignoreInstance(safezonesFolder)
safezonesFolder.DescendantAdded:Connect(function(descendant) ignoreInstance(descendant) end)

-- ----------------------------- ------------ DEBUGGING UTILS ------------ -----------------------------

local DEBUG_ATTRIBUTE = "Debug"
local IS_DEBUG_ACTIVE = script:GetAttribute(DEBUG_ATTRIBUTE) or false
local debugBall: Part = Instance.new("Part") do
	debugBall = Instance.new("Part")
	debugBall.Shape = Enum.PartType.Ball
	debugBall.Size = Vector3.new(0.3, 0.3, 0.3)
	debugBall.Anchored = true
	debugBall.CanCollide = false
	debugBall.Material = Enum.Material.Neon
	debugBall.Color = Color3.fromRGB(0, 255, 0)
	debugBall.Transparency = 0.5
	debugBall.Parent = if IS_DEBUG_ACTIVE then Workspace else nil
	
	-- Ignore raycasts for the ball
	ignoreInstance(debugBall)
end

script:GetAttributeChangedSignal(DEBUG_ATTRIBUTE):Connect(function()
	IS_DEBUG_ACTIVE = script:GetAttribute(DEBUG_ATTRIBUTE)
	debugBall.Parent = if IS_DEBUG_ACTIVE then Workspace else nil
end)

-- ----------------------------- ----------- HELPER FUNCTIONS ------------ -----------------------------

local function isGate(instance: Instance?): boolean
	return
		instance ~= nil and
		instance:GetAttribute("GateID") ~= nil
end

local function isNode(instance: Instance?): boolean
	return
		instance ~= nil and
		instance:IsA("BasePart") and -- Assumes BasePart to access Position in closestNodeToPointerOfPointedGate
		instance:GetAttribute("NodeType") ~= nil
end

local function gateFromDescendant(descendant: Instance?): Instance?
	if descendant == nil then return nil end
	
	local instance = descendant:FindFirstAncestorWhichIsA("Model")
	return (isGate(instance) and instance) or nil
end

local function closestNodeToPointerOfPointedGate(gate: Instance?, hitPos: Vector3?): Instance?
	if not gate or not isGate(gate) or not hitPos then return end
	
	local nodes = gate:FindFirstChild("Nodes")
	if nodes == nil then
		error("Pointed gate doesn't have the 'Gate' structure (Gate -> Nodes: Folder -> { Inputs: Folder, Outputs: Folder })")
		return nil
	end
	local inputs = nodes:FindFirstChild("Inputs")
	local outputs = nodes:FindFirstChild("Outputs")
	if inputs == nil or outputs == nil then
		error("Pointed gate doesn't have the 'Gate' structure (Gate -> Nodes: Folder -> { Inputs: Folder, Outputs: Folder })")
		return nil
	end
	
	local closest: Instance? = nil
	local maxDistance = math.huge
	for _, folder in { inputs, outputs } do
		for _, node: BasePart in folder:GetChildren() do
			if not isNode(node) then continue end
			
			local distance = (hitPos - node.Position).Magnitude
			if distance < maxDistance then
				closest, maxDistance = node, distance
			end
		end
	end
	
	return closest
end

-- ----------------------------- ----------- MODULE DEFINITION ----------- -----------------------------

-- Events
local hoverChanged = Instance.new("BindableEvent")
local gateHovered = Instance.new("BindableEvent")
local nodeHovered = Instance.new("BindableEvent")
local interacted = Instance.new("BindableEvent")

local PointerService = {
	AddToFilter = ignoreInstance,
	RemoveFromFilter = restoreInstance,
	
	-- READ-ONLY
	HoveredInstance = nil :: Instance?,
	HoveredGate = nil :: Model?,
	HoveredNode = nil :: BasePart?,
	HitPosition = nil :: Vector3?,
	
	OnHoverChanged = hoverChanged.Event,
	OnGateHovered = gateHovered.Event,
	OnNodeHovered = nodeHovered.Event,
	OnInteraction = interacted.Event,
}

-- ----------------------------- ------------ INPUT DETECTION ----------- -----------------------------

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		interacted:Fire(
			PointerService.HoveredInstance,
			PointerService.HoveredGate,
			PointerService.HoveredNode
		)
	end
end)

RunService.RenderStepped:Connect(function()
	local camera = Workspace.CurrentCamera
	if not camera then return end
	
	local ray = camera:ViewportPointToRay(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
	local currentResult = Workspace:Raycast(ray.Origin, ray.Direction * MAX_RAY_DISTANCE, rayParams)
	
	local instance = (currentResult and currentResult.Instance) or nil
	local position = (currentResult and currentResult.Position) or nil
	PointerService.HitPosition = position
	
	-- Traslate the debug ball to cursor
	if IS_DEBUG_ACTIVE then
		if position then
			debugBall.Position = currentResult.Position
			debugBall.Transparency = 0.5
		else
			debugBall.Transparency = 1
		end
	end
	
	-- If hovered part changed
	if instance ~= PointerService.HoveredInstance then
		if IS_DEBUG_ACTIVE then print("Pointing to " .. tostring(PointerService.HitPosition or "nothing")) end
		PointerService.HoveredInstance = instance
		
		local gate = gateFromDescendant(instance)
		local node = closestNodeToPointerOfPointedGate(gate, position)
		
		if gate ~= PointerService.HoveredGate then
			PointerService.HoveredGate = gate
			if IS_DEBUG_ACTIVE then print("Changed hovered gate to: " .. ((gate and gate.Name) or "nil")) end
			if gate then gateHovered:Fire(gate) end
		end
		
		if node ~= PointerService.HoveredNode then
			PointerService.HoveredNode = node
			if IS_DEBUG_ACTIVE then print("Changed hovered node to: " .. ((node and node.Name) or "nil")) end
			if node then nodeHovered:Fire(node) end
		end
		
		hoverChanged:Fire(instance, gate, node)
		return
	end

	-- If position changed, but on the same part, update the closest node
	if PointerService.HoveredGate then
		local node = closestNodeToPointerOfPointedGate(PointerService.HoveredGate, position)
		if node ~= PointerService.HoveredNode then
			PointerService.HoveredNode = node
			if IS_DEBUG_ACTIVE then print("Changed hovered node to: " .. ((node and node.Name) or "nil")) end
			if node then nodeHovered:Fire(node) end
		end
	end
end)

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return PointerService
