--[[ PLAYER FSM
		To prevent glitches on tool drops, deaths, and
		the undefined state of not holding any tool, a Finite State Machine
		is implemented.
		
		Each Tool should provide a ModuleScript that implements the State interface,
		and if no Tool is equipped, defaults to the "Display owner name" behaviour.
]]

-- Requires and Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Effects
local EffectsService = require(ReplicatedStorage:WaitForChild("EffectsService"))

-- References
local DefaultStateClass = require(script.DisplayNamesOnHoverState)
local player = Players.LocalPlayer

-- Connections
local characterConnections = {}

-- ----------------------------- ------------ STATE HANDLING ------------ -----------------------------

local currentState = nil -- Required module state

local function resetCurrentState()
	if currentState and currentState.Exit then
		currentState:Exit() -- currentState:Exit() should clean up all resources used by that tool
		currentState = nil
	end
	
	for _, connection: RBXScriptConnection in ipairs(characterConnections) do
		connection:Disconnect()
	end
	table.clear(characterConnections)
end

local function transitionTo(nextState)
	if currentState and currentState.Exit then
		currentState:Exit()
	end
	
	currentState = nextState
	
	if currentState and currentState.Enter then
		currentState:Enter()
	end
end

-- ----------------------------- --------- CHARACTER CONNECTIONS --------- -----------------------------

local function initializeCharacter(character: Model)
	resetCurrentState()
	
	local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid
	if not humanoid then error("Unexpected Error: Humanoid did not load in time.") end
	
	local defaultState = DefaultStateClass.new(player, character)
	transitionTo(defaultState)
	
	local toolEquippedConnection = character.ChildAdded:Connect(function(tool)
		if not tool:IsA("Tool") then return end
		
		local stateModule = tool:FindFirstChild(tool.Name .. ".State")
		if not stateModule then return end
		
		local toolState = require(stateModule).new(player, character, tool)
		transitionTo(toolState)
	end)
	table.insert(characterConnections, toolEquippedConnection)
	
	local toolUnequippedConnection = character.ChildRemoved:Connect(function(tool)
		if not tool:IsA("Tool") then return end
		
		-- Defered to handle switching from one tool to another same frame
		task.defer(function()
			if character and character:IsDescendantOf(Workspace) and not character:FindFirstChildOfClass("Tool") then
				local defaultState = DefaultStateClass.new(player, character)
				transitionTo(defaultState)
			end
		end)
	end)
	table.insert(characterConnections, toolUnequippedConnection)
	
	local deathConnection = humanoid.Died:Connect(resetCurrentState)
	table.insert(characterConnections, deathConnection)
end

player.CharacterAdded:Connect(initializeCharacter)
if player.Character then initializeCharacter(player.Character) end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if currentState and currentState.Activated then
			currentState:Activated()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if currentState and currentState.Deactivated then
			currentState:Deactivated()
		end
	end
end)
