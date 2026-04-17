--!strict

local Players = game:GetService("Players")

export type TSaveSummary = {
	Title: string,
	GateCount: number,
	WireCount: number,
	UpdatedAt: number,
}

type TCallbacks = {
	OnSave: (saveName: string) -> (),
	OnLoad: (saveName: string) -> (),
	OnErase: (saveName: string) -> (),
	OnSelectionChanged: (saveName: string?) -> (),
	OnSaveNameChanged: (saveName: string) -> (),
}

local ClipboardUI = {}

local activeGui: ScreenGui?
local statusLabel: TextLabel?
local saveButton: TextButton?
local loadButton: TextButton?
local eraseButton: TextButton?
local saveNameBox: TextBox?
local listFrame: ScrollingFrame?
local callbacks: TCallbacks?

local currentSaves: { TSaveSummary } = {}
local selectedSaveName: string?
local saveEnabled = false
local loadEnabled = false
local loadArmed = false
local eraseEnabled = false

local COLORS = {
	Background = Color3.fromRGB(25, 28, 34),
	Panel = Color3.fromRGB(37, 42, 52),
	PanelAlt = Color3.fromRGB(48, 53, 64),
	PanelSelected = Color3.fromRGB(77, 94, 126),
	Text = Color3.fromRGB(244, 246, 250),
	Muted = Color3.fromRGB(167, 174, 189),
	Accent = Color3.fromRGB(255, 214, 102),
	Disabled = Color3.fromRGB(82, 88, 99),
	LoadArmed = Color3.fromRGB(100, 211, 156),
	Danger = Color3.fromRGB(215, 66, 66),
	DangerDisabled = Color3.fromRGB(100, 58, 58),
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

local function refreshListSelectionVisuals()
	if listFrame == nil then
		return
	end

	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("TextButton") then
			local isSelected = child:GetAttribute("SaveName") == selectedSaveName
			child.BackgroundColor3 = if isSelected then COLORS.PanelSelected else COLORS.PanelAlt
		end
	end
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

	local isActive = loadArmed or loadEnabled
	loadButton.Active = isActive
	loadButton.AutoButtonColor = isActive

	if loadArmed then
		loadButton.BackgroundColor3 = COLORS.LoadArmed
		loadButton.TextColor3 = Color3.fromRGB(20, 46, 31)
		loadButton.Text = "Click to Place"
	elseif loadEnabled then
		loadButton.BackgroundColor3 = COLORS.Panel
		loadButton.TextColor3 = COLORS.Text
		loadButton.Text = "Load"
	else
		loadButton.BackgroundColor3 = COLORS.Disabled
		loadButton.TextColor3 = COLORS.Muted
		loadButton.Text = "Load"
	end
end

local function applyEraseButtonState()
	if eraseButton == nil then
		return
	end

	eraseButton.Active = eraseEnabled
	eraseButton.AutoButtonColor = eraseEnabled
	eraseButton.BackgroundColor3 = if eraseEnabled then COLORS.Danger else COLORS.DangerDisabled
	eraseButton.TextColor3 = if eraseEnabled then COLORS.Text else COLORS.Muted
end

local function clearSaveRows()
	if listFrame == nil then
		return
	end

	for _, child in ipairs(listFrame:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function buildSaveRow(summary: TSaveSummary): TextButton
	local button = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = COLORS.PanelAlt,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
	}, {
		create("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
	}) :: TextButton
	button:SetAttribute("SaveName", summary.Title)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 18),
		Font = Enum.Font.GothamBold,
		Text = summary.Title,
		TextColor3 = COLORS.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = button,
	})

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 26),
		Size = UDim2.new(1, -24, 0, 14),
		Font = Enum.Font.Gotham,
		Text = string.format("%d gates, %d wires", summary.GateCount, summary.WireCount),
		TextColor3 = COLORS.Muted,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = button,
	})

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 39),
		Size = UDim2.new(1, -24, 0, 12),
		Font = Enum.Font.Gotham,
		Text = os.date("!%Y-%m-%d %H:%M", math.floor(summary.UpdatedAt)),
		TextColor3 = COLORS.Muted,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = button,
	})

	button.MouseButton1Click:Connect(function()
		selectedSaveName = summary.Title
		refreshListSelectionVisuals()
		if callbacks then
			callbacks.OnSelectionChanged(selectedSaveName)
		end
	end)

	return button
end

function ClipboardUI.Open(newCallbacks: TCallbacks)
	ClipboardUI.Close()
	callbacks = newCallbacks
	currentSaves = {}
	selectedSaveName = nil
	saveEnabled = false
	loadEnabled = false
	loadArmed = false
	eraseEnabled = false

	activeGui = Instance.new("ScreenGui")
	activeGui.Name = "ClipboardGui"
	activeGui.ResetOnSpawn = false
	activeGui.Parent = Players.LocalPlayer.PlayerGui

	local panel = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 18, 0.5, 0),
		Size = UDim2.fromOffset(330, 420),
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
		Text = "Clipboard",
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
		Text = "Drag to select gates, save them under a name, then choose a stored save to load or erase.",
		TextColor3 = COLORS.Muted,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = panel,
	})

	saveNameBox = create("TextBox", {
		Position = UDim2.fromOffset(16, 76),
		Size = UDim2.new(1, -32, 0, 36),
		BackgroundColor3 = COLORS.Panel,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		PlaceholderText = "Save name",
		Text = "",
		TextColor3 = COLORS.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 10) }),
		create("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
	}) :: TextBox
	saveNameBox:GetPropertyChangedSignal("Text"):Connect(function()
		if callbacks then
			callbacks.OnSaveNameChanged(saveNameBox.Text)
		end
	end)

	saveButton = create("TextButton", {
		Position = UDim2.fromOffset(16, 122),
		Size = UDim2.fromOffset(96, 36),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "Save",
		TextSize = 14,
		Parent = panel,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 10) }),
	}) :: TextButton
	saveButton.MouseButton1Click:Connect(function()
		if saveEnabled and callbacks and saveNameBox then
			callbacks.OnSave(saveNameBox.Text)
		end
	end)

	loadButton = create("TextButton", {
		Position = UDim2.fromOffset(120, 122),
		Size = UDim2.fromOffset(96, 36),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "Load",
		TextSize = 14,
		Parent = panel,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 10) }),
	}) :: TextButton
	loadButton.MouseButton1Click:Connect(function()
		if callbacks and selectedSaveName and (loadEnabled or loadArmed) then
			callbacks.OnLoad(selectedSaveName)
		end
	end)

	eraseButton = create("TextButton", {
		Position = UDim2.fromOffset(224, 122),
		Size = UDim2.fromOffset(90, 36),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "Erase",
		TextSize = 14,
		Parent = panel,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 10) }),
	}) :: TextButton
	eraseButton.MouseButton1Click:Connect(function()
		if eraseEnabled and callbacks and selectedSaveName then
			callbacks.OnErase(selectedSaveName)
		end
	end)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 170),
		Size = UDim2.new(1, -32, 0, 16),
		Font = Enum.Font.GothamBold,
		Text = "Saved Builds",
		TextColor3 = COLORS.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})

	listFrame = create("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 192),
		Size = UDim2.new(1, -32, 0, 170),
		BackgroundColor3 = COLORS.Panel,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = panel,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 10) }),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
		create("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: ScrollingFrame

	statusLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 374),
		Size = UDim2.new(1, -32, 0, 30),
		Font = Enum.Font.Gotham,
		Text = "Drag on the board to start a selection.",
		TextColor3 = COLORS.Muted,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = panel,
	}) :: TextLabel

	applySaveButtonState()
	applyLoadButtonState()
	applyEraseButtonState()
end

function ClipboardUI.SetSaveEnabled(enabled: boolean)
	saveEnabled = enabled
	applySaveButtonState()
end

function ClipboardUI.SetLoadEnabled(enabled: boolean)
	loadEnabled = enabled
	applyLoadButtonState()
end

function ClipboardUI.SetLoadArmed(armed: boolean)
	loadArmed = armed
	applyLoadButtonState()
end

function ClipboardUI.SetEraseEnabled(enabled: boolean)
	eraseEnabled = enabled
	applyEraseButtonState()
end

function ClipboardUI.SetStatus(text: string, isError: boolean?)
	if statusLabel == nil then
		return
	end

	statusLabel.Text = text
	statusLabel.TextColor3 = if isError then COLORS.Error else COLORS.Muted
end

function ClipboardUI.GetSaveName(): string
	return if saveNameBox then saveNameBox.Text else ""
end

function ClipboardUI.SetSaveName(text: string)
	if saveNameBox then
		saveNameBox.Text = text
	end
end

function ClipboardUI.GetSelectedSaveName(): string?
	return selectedSaveName
end

function ClipboardUI.SetSelectedSaveName(saveName: string?)
	selectedSaveName = saveName
	refreshListSelectionVisuals()
end

function ClipboardUI.SetSaves(saves: { TSaveSummary })
	currentSaves = saves
	clearSaveRows()

	local hasSelection = false
	for _, summary in ipairs(currentSaves) do
		if summary.Title == selectedSaveName then
			hasSelection = true
		end
		buildSaveRow(summary).Parent = listFrame
	end

	if not hasSelection then
		selectedSaveName = nil
	end

	if listFrame and #currentSaves == 0 then
		create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 24),
			Font = Enum.Font.Gotham,
			Text = "No saved builds yet.",
			TextColor3 = COLORS.Muted,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = listFrame,
		})
	end

	refreshListSelectionVisuals()
	if callbacks then
		callbacks.OnSelectionChanged(selectedSaveName)
	end
end

function ClipboardUI.Close()
	if activeGui then
		activeGui:Destroy()
		activeGui = nil
	end

	statusLabel = nil
	saveButton = nil
	loadButton = nil
	eraseButton = nil
	saveNameBox = nil
	listFrame = nil
	callbacks = nil
	currentSaves = {}
	selectedSaveName = nil
	saveEnabled = false
	loadEnabled = false
	loadArmed = false
	eraseEnabled = false
end

return ClipboardUI
