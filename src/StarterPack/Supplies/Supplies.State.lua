--[[ SUPPLIES TOOL
		Point to a gate to copy it, click again to place it.
		Copied gates store visual data and attribute data, but not permission data.
]]

-- Requires and Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalServices = StarterPlayer.StarterPlayerScripts.Services
local MessageService = require(StarterPlayer.StarterPlayerScripts.Services.MessageService)
local PointerService = require(LocalServices.PointerService)
local GridService = require(ReplicatedStorage.GridService)

-- References
local buildModeGuiFolder = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("BuildMode")
local baseHighlightPrefab: SelectionBox = buildModeGuiFolder.MoveBaseHighlight
local gridTexturePrefab: Texture = buildModeGuiFolder.Grid
local nameGuiPrefab: BillboardGui = buildModeGuiFolder.MoveNamePopup

local Terrain = Workspace:WaitForChild("Terrain")
local Baseplate = Terrain:WaitForChild("Baseplate")
local GatesFolder = Workspace:WaitForChild("Gates")

-- Events
local permissionQuery: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Queries"):WaitForChild("Permission")
local spawnEvent: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Events"):WaitForChild("Spawn")

-- State definition
local State = {}
State.__index = State

-- ----------------------------- ----------- HELPER FUNCTIONS ------------ -----------------------------

local function cleanUpWires(gate: Instance)
	local nodes = gate:FindFirstChild("Nodes")
	local inputs = nodes and nodes:FindFirstChild("Inputs")
	local outputs = nodes and nodes:FindFirstChild("Outputs")
	if not nodes or not inputs or not outputs then return end
	
	for _, child in ipairs(inputs:GetChildren()) do if child:IsA("Beam") then child:Destroy() end end
	for _, child in ipairs(outputs:GetChildren()) do if child:IsA("Beam") then child:Destroy() end end
end

local function DeactivationContext(): "Skybox" | "Invalid" | "Valid"
	local hit, instance = PointerService.HitPosition, PointerService.HoveredInstance :: Instance
	if not hit or not instance then return "Skybox" end
	
	if instance:IsDescendantOf(Terrain.GateStands)
		or instance:IsDescendantOf(Terrain.Incinerators)
		or instance:IsDescendantOf(GatesFolder.Server) then return "Invalid" end
	return "Valid"
end

function State:showUIs()
	if not self.IsEquipped or not self.Ghost then return end
	
	local base = self.Ghost:FindFirstChild("Base")
	if base then
		self.BaseHighlight.Adornee = base
		self.BaseHighlight.Visible = true
		self.BaseHighlight.Parent = self.Ghost
	end
	
	if Baseplate then
		self.GridTexture.Parent = Baseplate
	end
	
	self.NameGui.Adornee = self.Ghost
	self.NameGui.Enabled = true
	self.NameGui.TextLabel.Text = self.Ghost.Name
	self.NameGui.Parent = self.Ghost
end

function State:hideUIs()
	if self.BaseHighlight then
		self.BaseHighlight.Adornee = nil
		self.BaseHighlight.Visible = false
		self.BaseHighlight.Parent = nil
	end
	
	if self.GridTexture then
		self.GridTexture.Parent = nil
	end
	
	if self.NameGui then
		self.NameGui.Adornee = nil
		self.NameGui.Enabled = false
		self.NameGui.TextLabel.Text = "No Gate"
		self.NameGui.Parent = nil
	end
end

function State:MoveGhostToPointer()
	if not self.IsEquipped or not self.Gate then return end
	
	local position = PointerService.HitPosition
	if not position then
		self.Ghost:PivotTo(CFrame.new(0, -100, 0))
		return
	end
	
	local cframe = GridService.fromCFrame(CFrame.new(PointerService.HitPosition) * CFrame.Angles(0, math.rad(self.Rotation), 0))
	if PointerService.HoveredGate then
		cframe = GridService.Move(cframe, cframe.Position + GridService.getSurfaceNormal(PointerService.HitPosition, GridService.fromCFrame(PointerService.HoveredGate:GetPivot())))
	end
	self.Ghost:PivotTo(cframe._cframe)
end

function State:CleanUpGhost()
	self:hideUIs()
	
	if self.RenderConnection then
		self.RenderConnection:Disconnect()
		self.RenderConnection = nil
	end
	
	if self.RotationConnection then
		self.RotationConnection:Disconnect()
		self.RotationConnection = nil
	end
	
	if self.Ghost then
		self.Ghost:Destroy()
		self.Ghost = nil
	end
	
	self.Gate = nil
	self.Rotation = 0
	self.Active = false
end

-- ----------------------------- --------- STATE IMPLEMENTATION ---------- -----------------------------

function State.new(player: Player)
	local self = setmetatable({}, State)
	self.Player = player
	self.Rotation = 0
	
	self.BaseHighlight = nil
	self.GridTexture = nil
	self.NameGui = nil
	
	self.Gate = nil
	self.Ghost = nil
	
	self.RenderConnection = nil
	self.RotationConnection = nil
	
	self.Active = false
	self.IsEquipped = true
	
	return self
end

function State:Enter()
	self.BaseHighlight = baseHighlightPrefab:Clone()
	self.GridTexture = gridTexturePrefab:Clone()
	self.NameGui = nameGuiPrefab:Clone()
	
	self:hideUIs()
end

function State:Activated()
	if not self.IsEquipped then return end
	
	if self.Active then -- We are placing the gate
		local context = DeactivationContext()
		
		local gateID = self.Gate and self.Gate:GetAttribute("GateID")
		local currentPivot = self.Ghost and self.Ghost:GetPivot()
		
		if not gateID or not self.Gate or not currentPivot then
			self:CleanUpGhost()
			return
		end
		
		if context == "Valid" then
			local ghost = self.Ghost
			self.Ghost = nil
			task.spawn(function()
				local success, message = spawnEvent:InvokeServer(gateID, currentPivot)
				ghost:Destroy()
				if not self.IsEquipped then return end
				
				if not success then
					MessageService.SendMessage(message)
				end
			end)
		end
		
		self:CleanUpGhost()
	
	else -- We are copying the gate
		local gate = PointerService.HoveredGate
		if gate == nil then return end
		
		local gateID = gate:GetAttribute("GateID")
		if not gateID then return end
		
		-- Create ghost before query for 0 latency
		self.Gate = gate
		self.Ghost = self.Gate:Clone()
		cleanUpWires(self.Ghost)
		self.Ghost.Parent = Workspace
		PointerService.AddToFilter(self.Ghost)
		
		-- Rotate the preview model
		local _, radians = GridService.fromCFrame(self.Ghost:GetPivot())._cframe:ToOrientation()
		self.Rotation = math.deg(radians)
		
		self:showUIs()
		self.RenderConnection = RunService.RenderStepped:Connect(function()
			self:MoveGhostToPointer()
		end)
		
		self.RotationConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed or not self.Active then return end
		
			if input.KeyCode == Enum.KeyCode.R then
				self.Rotation = (self.Rotation + 90) % 360
			end
		end)
		
		self.Active = true
		
		-- Asking for forgiveness is better than asking for permission
		local ghost = self.Ghost
		task.spawn(function()
			local success, message = permissionQuery:InvokeServer(gateID, "Spawn")
			if not self.IsEquipped then return end
			
			if self.Ghost == ghost then
				if not success then
					MessageService.SendMessage(message)
					self:CleanUpGhost()
				end
			end
		end)
	end
end

function State:Deactivated()
end

function State:Exit()
	if not self.IsEquipped then return end
	self.IsEquipped = false
	
	self:CleanUpGhost()
	
	if self.BaseHighlight then self.BaseHighlight:Destroy() end
	if self.GridTexture then self.GridTexture:Destroy() end
	if self.NameGui then self.NameGui:Destroy() end
	
	table.clear(self)
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return State
