--!strict
--[[ CUSTOMIZER TOOL
		Edits Gate Visuals.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local LocalServices = StarterPlayerScripts.Services

local PointerService = require(LocalServices.PointerService)
local MessageService = require(LocalServices.MessageService)

local NeedleMode = require(StarterPlayerScripts.Tool.NeedleMode)
local CustomizerUI = require(StarterPlayerScripts.Tool.CustomizerUI)

local GetGateInfo = ReplicatedStorage.Client.Queries.GateConfiguration

local Tool = script.Parent

local function Activated()
	local gate = PointerService.HoveredGate
	if not gate then
		return
	end

	local id = gate:GetAttribute("GateId")
	if not id then
		return
	end

	local allowed, context = GetGateInfo:InvokeServer(id)

	if not allowed then
		MessageService.SendMessage(context or "No permissions to customize this gate")
		return
	end

	if not context or not context.Visuals then
		MessageService.SendMessage("Failed to fetch gate visuals")
		return
	end

	CustomizerUI.Open(id, context.Visuals)
end

local function Equipped()
	NeedleMode.Start()
end

local function Unequipped()
	NeedleMode.Stop()
	CustomizerUI.Close()
end

Tool.Equipped:Connect(Equipped)
Tool.Unequipped:Connect(Unequipped)
Tool.Activated:Connect(Activated)
