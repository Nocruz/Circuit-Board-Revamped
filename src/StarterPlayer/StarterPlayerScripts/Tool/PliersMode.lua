--!strict
--[[ PLIERS MODE
		Singleton that handles the plier
		Enables visuals mostly
]]

-- Requires and services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local LocalServices = StarterPlayerScripts.Services

local PointerService = require(LocalServices.PointerService)

-- Debugging
local Logger = require(ReplicatedStorage.Services.LoggerService)
local log = Logger.new("PliersMode")

-- Visuals
local HighlightPrefab: SelectionBox = ReplicatedStorage.Client.UI.PliersHighlight
local COLOR_SELECTED: ColorSequence = ColorSequence.new(Color3.new(1, 0, 0))

-- State
local redBox: SelectionBox? = nil

local hoverConnection: RBXScriptConnection? = nil

local lastGate: Model? = nil

local lastWire: Beam? = nil
local lastColor: ColorSequence? = nil

local PliersMode = { }

-- ----------------------------- --------- HELPER METHODS -------- ------------------------------

local function isWire(instance: Instance?): (boolean, Beam?)
	if instance and instance:IsA("Part") and instance.Name == "Hitbox" then
		local parent = instance.Parent
		if parent ~= nil and typeof(parent) == "Instance" and parent:IsA("Beam") then
			return true, parent
		end
	end
	return false, nil
end

local function resetLastWire()
	if lastWire then
		lastWire.Color = lastColor :: ColorSequence
		lastWire = nil
		lastColor = nil
	end
end

local function showHighlight(model: Model)
	if redBox then redBox:Destroy() end
	redBox = HighlightPrefab:Clone(); assert(redBox)
	redBox.Adornee = model
	redBox.Parent = model
end

local function hideHighlight()
	if redBox then
		redBox:Destroy()
		redBox = nil
	end
end

local function highlightHovered(instance: Instance?, gate: Model?)
	local validWire, wireInstance = isWire(instance)

	if validWire and wireInstance then
		if lastWire ~= wireInstance then
			resetLastWire()
			hideHighlight()
			lastGate = nil

			lastWire = wireInstance; assert(lastWire)
			lastColor = lastWire.Color
			lastWire.Color = COLOR_SELECTED
			log.info("Hovering wire")
		end
		return
	end

	resetLastWire()

	if not gate then
		hideHighlight()
		lastGate = nil
		log.info("Not hovering anything")
	elseif lastGate ~= gate then
		hideHighlight()
		showHighlight(gate)
		lastGate = gate
		log.info("Hovering gate")
	end
end

-- ----------------------------- ----------- LIFECYCLE ----------- ------------------------------

function PliersMode.Start()
	if redBox then redBox:Destroy() end
	
	if hoverConnection then hoverConnection:Disconnect() end
	hoverConnection = PointerService.OnHoverChanged:Connect(highlightHovered)
	highlightHovered(PointerService.HoveredInstance, PointerService.HoveredGate)
	
	log.info("Started PliersMode")
end

function PliersMode.Stop()
	if redBox then hideHighlight() end
	if hoverConnection then hoverConnection:Disconnect(); hoverConnection = nil end
	
	resetLastWire()
	
	lastWire = nil
	lastGate = nil
	
	log.info("Stopped PliersMode")
end

-- ----------------------------- --------- END OF MODULE ---------- -----------------------------

return PliersMode
