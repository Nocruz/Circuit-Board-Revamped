--[[ TWEEZERS TOOL
		Point to a gate to drag it, click again to place it.
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

-- Events
local permissionQuery: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Queries"):WaitForChild("Permission")
local moveEvent: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Events"):WaitForChild("Move")
local destroyEvent: RemoteFunction =ReplicatedStorage:WaitForChild("Client"):WaitForChild("Events"):WaitForChild("Destroy")

-- State definition
local State = {}
State.__index = State

-- ----------------------------- ----------- HELPER FUNCTIONS ------------ -----------------------------

local function DeactivationContext(): "Skybox" | "Invalid" | "Valid"
	local hit, instance = PointerService.HitPosition, PointerService.HoveredInstance :: Instance
	if not hit then return "Skybox" end
	if instance:IsDescendantOf(Terrain.GateStands) or instance:IsDescendantOf(Terrain.Incinerators) or instance:IsDescendantOf(workspace.Gates.Server) then return "Invalid" end
	return "Valid"
end

function State:showUIs()
	self.BaseHighlight.Adornee = self.Gate:FindFirstChild("Base") or error("Gate had no 'Base' children")
	self.BaseHighlight.Visible = true
	self.BaseHighlight.Parent = self.Gate
	
	self.GridTexture.Parent = Workspace:FindFirstChild("Terrain"):FindFirstChild("Baseplate") or error("Workspace.Terrain.Baseplate does not exist")
	
	self.NameGui.Adornee = self.Gate
	self.NameGui.Enabled = true
	self.NameGui.TextLabel.Text = self.Gate.Name
	self.NameGui.Parent = self.Gate
end

function State:hideUIs()
	self.BaseHighlight.Adornee = nil
	self.BaseHighlight.Visible = false
	self.BaseHighlight.Parent = nil
	
	self.GridTexture.Parent = nil
	
	self.NameGui.Adornee = nil
	self.NameGui.Enabled = false
	self.NameGui.TextLabel.Text = "No Gate"
	self.NameGui.Parent = nil
end

function State:MoveGhostToPointer()
	local position = PointerService.HitPosition
	if not position then
		self.Gate:PivotTo(CFrame.new(0, -100, 0))
		return
	end
	
	local cframe = GridService.fromCFrame(CFrame.new(PointerService.HitPosition) * CFrame.Angles(0, math.rad(self.Rotation), 0))
	if PointerService.HoveredGate then
		cframe = GridService.Move(cframe, cframe.Position + GridService.getSurfaceNormal(PointerService.HitPosition, GridService.fromCFrame(PointerService.HoveredGate:GetPivot())))
	end
	self.Gate:PivotTo(cframe._cframe)
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
	
	if self.Gate then
		PointerService.RemoveFromFilter(self.Gate)
		self.Gate = nil
	end
	
	self.GatePreviousCFrame = nil
	self.Rotation = 0
	self.Active = false
end

-- ----------------------------- --------- STATE IMPLEMENTATION ---------- -----------------------------

function State.new(player: Player, character: Model)
	local self = setmetatable({}, State)
	self.Player = player
	self.Rotation = 0
	
	self.BaseHighlight = nil
	self.GridTexture = nil
	self.NameGui = nil
	
	self.Gate = nil
	self.GatePreviousCFrame = nil
	
	self.RenderConnection = nil
	self.RotationConnection = nil
	
	self.Active = false
	
	return self
end

function State:Enter()
	self.BaseHighlight = baseHighlightPrefab:Clone()
	self.GridTexture = gridTexturePrefab:Clone()
	self.NameGui = nameGuiPrefab:Clone()
	
	self:hideUIs()
end

function State:Activated()
	if self.Active then -- We are placing the gate
		local context = DeactivationContext()
		if context == "Valid" then
			local success, message = moveEvent:InvokeServer(self.Gate:GetAttribute("GateID"), self.Gate:GetPivot())
			if not success then
				MessageService.SendMessage(message)
			end
		elseif context == "Invalid" then
			local success, message = destroyEvent:InvokeServer(self.Gate:GetAttribute("GateID"))
			if not success then
				MessageService.SendMessage(message)
			end
		else
			self.Gate:PivotTo(self.GatePreviousCFrame)
			print("Canceled move!")
		end
		
		self:CleanUpGhost()
	else -- We are copying the gate
		local gate = PointerService.HoveredGate
		if gate == nil then return end
		
		local success, message = permissionQuery:InvokeServer(gate:GetAttribute("GateID"), "Move")
		if not success then
			MessageService.SendMessage(message)
			return
		end
		
		self.Gate = gate
		self.GatePreviousCFrame = self.Gate:GetPivot()
		PointerService.AddToFilter(self.Gate)
		
		-- Rotate the preview model
		local _, radians = GridService.fromCFrame(self.Gate:GetPivot())._cframe:ToOrientation()
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
	end
end

function State:Deactivated()
end

function State:Exit()
	if self.Active then
		self.Gate:PivotTo(self.GatePreviousCFrame)
	end
	self:CleanUpGhost()
	
	self.BaseHighlight:Destroy()
	self.GridTexture:Destroy()
	self.NameGui:Destroy()
	
	table.clear(self)
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return State
