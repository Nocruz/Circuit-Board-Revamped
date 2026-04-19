--!strict
--[[ POINTER SERVICE (IMPROVED)
		Handles hover, click, and pointer movement for both desktop and mobile.
		Automatically filters out all player characters.
]]

-- Requires and Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- References
local camera = Workspace.CurrentCamera :: Camera

-- ----------------------------- ------- CONFIGURATION ----------- ----------------------------

local CONFIG = {
	MAX_RAY_DISTANCE = 1000,
	NODE_DETECTION_RADIUS = 5,
	HOVER_DEBOUNCE_TIME = 0.05,
	DEBUG_MODE = false,
}

-- ----------------------------- -------- RAYCAST SETUP --------- ----------------------------

local raycastFilter = Instance.new("Folder")
raycastFilter.Name = "RaycastFilter"
raycastFilter.Parent = Workspace
local Wires = workspace:WaitForChild("Wires")

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { raycastFilter, Wires }

-- ----------------------------- -------- DEBUG VISUALIZATION ------- ----------------------------

local debugBall: Part
if CONFIG.DEBUG_MODE then
	debugBall = Instance.new("Part")
	debugBall.Shape = Enum.PartType.Ball
	debugBall.Size = Vector3.new(0.3, 0.3, 0.3)
	debugBall.Anchored = true
	debugBall.CanCollide = false
	debugBall.Material = Enum.Material.Neon
	debugBall.Color = Color3.fromRGB(0, 255, 0)
	debugBall.Transparency = 0.5
	debugBall.Parent = raycastFilter
	table.insert(rayParams.FilterDescendantsInstances, debugBall)
end

-- ----------------------------- -------- EVENT SYSTEM --------- ----------------------------

local hoverChanged = Instance.new("BindableEvent")
local gateHovered = Instance.new("BindableEvent")
local nodeHovered = Instance.new("BindableEvent")
local interacted = Instance.new("BindableEvent")

-- ----------------------------- -------- STATE MANAGEMENT --------- ----------------------------

local PointerService = {
	RaycastFilter = raycastFilter,
	
	HoveredInstance = nil :: Instance?,
	HoveredGate = nil :: Model?,
	HoveredNode = nil :: BasePart?,
	HitPosition = nil :: Vector3?,
	
	OnHoverChanged = hoverChanged.Event,
	OnGateHovered = gateHovered.Event,
	OnNodeHovered = nodeHovered.Event,
	OnInteraction = interacted.Event,
}

local state = {
	running = false,
	renderConnection = nil :: RBXScriptConnection?,
	playerAddedConnection = nil :: RBXScriptConnection?,
	playerRemovingConnection = nil :: RBXScriptConnection?,
	characterConnections = {} :: { [Player]: RBXScriptConnection },
	
	lastPointerPos = nil :: Vector2?,
	lastRaycastResult = nil :: RaycastResult?,
	
	lastHoveredInstance = nil :: Instance?,
	lastHoveredGate = nil :: Model?,
	lastHoveredNode = nil :: BasePart?,
	
	lastHoverChangeTime = 0,
}

-- ----------------------------- ------- CHARACTER FILTERING ------- ----------------------------

--[[ 
	IsInstancePartOfCharacter(instance: Instance): boolean
	
	Checks if an instance belongs to any player's character.
	Returns true if instance is a descendant of a character model.
]]
local function IsInstancePartOfCharacter(instance: Instance): boolean
	for _, playerObj in ipairs(Players:GetPlayers()) do
		if playerObj.Character and instance:IsDescendantOf(playerObj.Character) then
			return true
		end
	end
	return false
end

--[[ 
	OnPlayerAdded(newPlayer: Player): void
	
	Sets up character change tracking for new player.
]]
local function OnPlayerAdded(newPlayer: Player)
	-- Disconnect old connection if exists
	if state.characterConnections[newPlayer] then
		state.characterConnections[newPlayer]:Disconnect()
	end
	
	-- Connect to character additions
	state.characterConnections[newPlayer] = newPlayer.CharacterAdded:Connect(function(char)
		-- When a character is added, update the raycast filter list
		-- (The filter will check membership on each raycast)
	end)
end

--[[ 
	OnPlayerRemoving(removingPlayer: Player): void
	
	Cleans up connections when player leaves.
]]
local function OnPlayerRemoving(removingPlayer: Player)
	if state.characterConnections[removingPlayer] then
		state.characterConnections[removingPlayer]:Disconnect()
		state.characterConnections[removingPlayer] = nil
	end
end

-- ----------------------------- ---------- GATE HELPERS ---------- ----------------------------

--[[ 
	IsGate(model: Model?): boolean
]]
local function IsGate(model: Model?): boolean
	if not model or not model:IsA("Model") then
		return false
	end
	
	return model:FindFirstChild("Decoration") ~= nil
		and model:FindFirstChild("Base") ~= nil
		and model:FindFirstChild("Nodes") ~= nil
end

--[[ 
	FindGateFromInstance(instance: Instance?): Model?
]]
local function FindGateFromInstance(instance: Instance?): Model?
	if not instance then
		return nil
	end
	
	if instance:IsA("Model") and IsGate(instance) then
		return instance
	end
	
	local parent = instance.Parent
	while parent and parent ~= Workspace do
		if parent:IsA("Model") and IsGate(parent) then
			return parent
		end
		parent = parent.Parent
	end
	
	return nil
end

--[[ 
	FindClosestNodeFromGate(gate: Model?, hitPos: Vector3?): BasePart?
]]
local function FindClosestNodeFromGate(gate: Model?, hitPos: Vector3?): BasePart?
	if not gate or not IsGate(gate) or not hitPos then
		return nil
	end
	
	local nodesFolder = gate:FindFirstChild("Nodes")
	if not nodesFolder then
		return nil
	end
	
	local closestNode = nil
	local closestDistance = CONFIG.NODE_DETECTION_RADIUS
	
	for _, child in ipairs(nodesFolder:GetChildren()) do
		if not child:IsA("BasePart") then
			continue
		end
		
		if not child:GetAttribute("Type") then
			continue
		end
		
		local distance = (hitPos - child.Position).Magnitude
		if distance < closestDistance then
			closestNode = child
			closestDistance = distance
		end
	end
	
	return closestNode
end

-- ----------------------------- --------- RAYCAST UPDATE --------- ----------------------------

--[[ 
	UpdateRaycast(): void
]]
local function UpdateRaycast()
	if not state.lastPointerPos or not state.running then
		return
	end
	
	local ray = camera:ScreenPointToRay(state.lastPointerPos.X, state.lastPointerPos.Y)
	state.lastRaycastResult = Workspace:Raycast(ray.Origin, ray.Direction * CONFIG.MAX_RAY_DISTANCE, rayParams)
	
	local hitInstance = (state.lastRaycastResult and state.lastRaycastResult.Instance) or nil
	local hitPosition = (state.lastRaycastResult and state.lastRaycastResult.Position) or nil
	
	PointerService.HitPosition = hitPosition
	
	-- Filter out hits that are part of characters
	if hitInstance and IsInstancePartOfCharacter(hitInstance) then
		hitInstance = nil
		hitPosition = nil
		PointerService.HitPosition = nil
	end
	
	-- Update debug visualization
	if CONFIG.DEBUG_MODE and debugBall then
		if hitPosition then
			debugBall.Position = hitPosition
			debugBall.Transparency = 0.5
		else
			debugBall.Transparency = 1
		end
	end
	
	-- Debounce
	local now = tick()
	local timeSinceLastChange = now - state.lastHoverChangeTime
	if timeSinceLastChange < CONFIG.HOVER_DEBOUNCE_TIME then
		return
	end
	
	-- Check if instance changed
	if hitInstance ~= state.lastHoveredInstance then
		state.lastHoveredInstance = hitInstance
		state.lastHoverChangeTime = now
		
		PointerService.HoveredInstance = hitInstance
		
		local newGate = FindGateFromInstance(hitInstance)
		local newNode = FindClosestNodeFromGate(newGate, hitPosition)
		
		if newGate ~= state.lastHoveredGate then
			state.lastHoveredGate = newGate
			PointerService.HoveredGate = newGate
			if newGate then
				gateHovered:Fire(newGate)
			end
		end
		
		if newNode ~= state.lastHoveredNode then
			state.lastHoveredNode = newNode
			PointerService.HoveredNode = newNode
			if newNode then
				nodeHovered:Fire(newNode)
			end
		end
		
		hoverChanged:Fire(hitInstance, newGate, newNode)
		return
	end
	
	-- Check if node changed
	if PointerService.HoveredGate and hitPosition then
		local newNode = FindClosestNodeFromGate(PointerService.HoveredGate, hitPosition)
		if newNode ~= state.lastHoveredNode then
			state.lastHoveredNode = newNode
			state.lastHoverChangeTime = now
			
			PointerService.HoveredNode = newNode
			if newNode then
				nodeHovered:Fire(newNode)
			end
			
			hoverChanged:Fire(hitInstance, PointerService.HoveredGate, newNode)
		end
	end
end

-- ----------------------------- --------- INPUT HANDLING --------- ----------------------------

local function OnInputChanged(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		state.lastPointerPos = input.Position
	elseif input.UserInputType == Enum.UserInputType.Touch then
		state.lastPointerPos = input.Position
	end
end

local function OnInputBegan(input: InputObject, gp: boolean)
	if gp then
		return
	end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		interacted:Fire(
			PointerService.HoveredInstance,
			PointerService.HoveredGate,
			PointerService.HoveredNode
		)
	end
end

-- ----------------------------- ---------- PUBLIC API ---------- ----------------------------

function PointerService.Start()
	if state.running then
		return
	end
	
	state.running = true
	
	-- Setup player tracking
	state.playerAddedConnection = Players.PlayerAdded:Connect(OnPlayerAdded)
	state.playerRemovingConnection = Players.PlayerRemoving:Connect(OnPlayerRemoving)
	
	-- Filter existing players
	for _, playerObj in ipairs(Players:GetPlayers()) do
		OnPlayerAdded(playerObj)
	end
	
	-- Start raycasting
	state.renderConnection = RunService.RenderStepped:Connect(UpdateRaycast)
	
	-- Setup input
	UserInputService.InputChanged:Connect(OnInputChanged)
	UserInputService.InputBegan:Connect(OnInputBegan)
end

function PointerService.Stop()
	if not state.running then
		return
	end
	
	state.running = false
	
	if state.renderConnection then
		state.renderConnection:Disconnect()
		state.renderConnection = nil
	end
	
	if state.playerAddedConnection then
		state.playerAddedConnection:Disconnect()
		state.playerAddedConnection = nil
	end
	
	if state.playerRemovingConnection then
		state.playerRemovingConnection:Disconnect()
		state.playerRemovingConnection = nil
	end
	
	for _, conn in pairs(state.characterConnections) do
		conn:Disconnect()
	end
	table.clear(state.characterConnections)
	
	PointerService.HoveredInstance = nil
	PointerService.HoveredGate = nil
	PointerService.HoveredNode = nil
	PointerService.HitPosition = nil
end

-- ----------------------------- ---------- INITIALIZATION ---------- ----------------------------

PointerService.Start()

-- ----------------------------- --------- END OF MODULE ---------- ----------------------------

return PointerService
