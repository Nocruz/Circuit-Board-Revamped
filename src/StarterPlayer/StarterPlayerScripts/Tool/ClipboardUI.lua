--!strict

local Players = game:GetService("Players")

type TCallbacks = {
	OnSave: () -> (),
	OnLoad: () -> (),
}

local ClipboardUI = {}

local activeGui: ScreenGui?
local statusLabel: TextLabel?
local saveButton: TextButton?
local loadButton: TextButton?
local callbacks: TCallbacks?

local saveEnabled = false
local loadArmed = false
local flashToken = 0

local COLORS = {
	Background = Color3.fromRGB(25, 28, 34),
	Panel = Color3.fromRGB(37, 42, 52),
	Text = Color3.fromRGB(244, 246, 250),
	Muted = Color3.fromRGB(167, 174, 189),
	Accent = Color3.fromRGB(255, 214, 102),
	Disabled = Color3.fromRGB(82, 88, 99),
	LoadArmed = Color3.fromRGB(100, 211, 156),
	Error = Color3.fromRGB(222, 90, 90),
}

local function create(className: string, props: { [string]: any }, children: { Instance }?): Instance
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	return instance
end

local function applySaveButtonState()
	if saveButton == nil then
		return
	end

	saveButton.Active = saveEnabled
	saveButton.AutoButtonColor = saveEnabled
	saveButton.BackgroundColor3 = if saveEnabled then COLORS.Accent else COLORS.Disabled
	saveButton.TextColor3 = if saveEnabled then Color3.fromRGB(34, 32, 27) else COLORS.Muted
end

local function applyLoadButtonState()
	if loadButton == nil then
		return
	end

	if loadArmed then
		loadButton.BackgroundColor3 = COLORS.LoadArmed
		loadButton.TextColor3 = Color3.fromRGB(20, 46, 31)
		loadButton.Text = "Click to Place"
	else
		loadButton.BackgroundColor3 = COLORS.Panel
		loadButton.TextColor3 = COLORS.Text
		loadButton.Text = "Load"
	end
end

function ClipboardUI.Open(newCallbacks: TCallbacks)
	ClipboardUI.Close()
	callbacks = newCallbacks
	saveEnabled = false
	loadArmed = false
	flashToken = 0

	activeGui = Instance.new("ScreenGui")
	activeGui.Name = "ClipboardGui"
	activeGui.ResetOnSpawn = false
	activeGui.Parent = Players.LocalPlayer.PlayerGui

	local panel = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 18, 0.5, 0),
		Size = UDim2.fromOffset(290, 150),
		BackgroundColor3 = COLORS.Background,
		BorderSizePixel = 0,
		Parent = activeGui,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 14) }),
		create("UIStroke", { Color = COLORS.Panel, Thickness = 2 }),
	})

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 22),
		Font = Enum.Font.GothamBold,
		Text = "Clipboard Draft",
		TextColor3 = COLORS.Text,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 38),
		Size = UDim2.new(1, -32, 0, 28),
		Font = Enum.Font.Gotham,
		Text = "Drag to box gates, save the current draft, then load it by clicking a placement point.",
		TextColor3 = COLORS.Muted,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = panel,
	})

	saveButton = create("TextButton", {
		Position = UDim2.fromOffset(16, 78),
		Size = UDim2.fromOffset(122, 38),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "Save",
		TextSize = 14,
		Parent = panel,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 10) }),
	}) :: TextButton
	saveButton.MouseButton1Click:Connect(function()
		if saveEnabled and callbacks then
			callbacks.OnSave()
		end
	end)

	loadButton = create("TextButton", {
		Position = UDim2.fromOffset(152, 78),
		Size = UDim2.fromOffset(122, 38),
		BackgroundColor3 = COLORS.Panel,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "Load",
		TextColor3 = COLORS.Text,
		TextSize = 14,
		Parent = panel,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 10) }),
	}) :: TextButton
	loadButton.MouseButton1Click:Connect(function()
		if callbacks then
			callbacks.OnLoad()
		end
	end)

	statusLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 122),
		Size = UDim2.new(1, -32, 0, 16),
		Font = Enum.Font.Gotham,
		Text = "Drag on the board to start a selection.",
		TextColor3 = COLORS.Muted,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	}) :: TextLabel

	applySaveButtonState()
	applyLoadButtonState()
end

function ClipboardUI.SetSaveEnabled(enabled: boolean)
	saveEnabled = enabled
	applySaveButtonState()
end

function ClipboardUI.SetLoadArmed(armed: boolean)
	loadArmed = armed
	applyLoadButtonState()
end

function ClipboardUI.FlashLoadUnavailable()
	if loadButton == nil then
		return
	end

	flashToken += 1
	local currentToken = flashToken
	loadButton.BackgroundColor3 = COLORS.Error
	loadButton.TextColor3 = COLORS.Text
	loadButton.Text = "No Save"

	task.delay(0.2, function()
		if currentToken ~= flashToken then
			return
		end
		applyLoadButtonState()
	end)
end

function ClipboardUI.SetStatus(text: string, isError: boolean?)
	if statusLabel == nil then
		return
	end

	statusLabel.Text = text
	statusLabel.TextColor3 = if isError then COLORS.Error else COLORS.Muted
end

function ClipboardUI.Close()
	if activeGui then
		activeGui:Destroy()
		activeGui = nil
	end

	statusLabel = nil
	saveButton = nil
	loadButton = nil
	callbacks = nil
	saveEnabled = false
	loadArmed = false
	flashToken = 0
end

return ClipboardUI
