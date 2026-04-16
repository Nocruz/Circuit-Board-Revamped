--!strict

local Players = game:GetService("Players")

export type TBuildSummary = {
	Title: string,
	GateCount: number,
	WireCount: number,
	UpdatedAt: number,
}

type TCallbacks = {
	OnSave: (title: string) -> (),
	OnRestore: (title: string) -> (),
	OnRefresh: () -> (),
	OnReset: () -> (),
}

local ClipboardUI = {}

local activeGui: ScreenGui?
local titleBox: TextBox?
local statusLabel: TextLabel?
local buildList: ScrollingFrame?
local callbacks: TCallbacks?

local COLORS = {
	Background = Color3.fromRGB(26, 28, 34),
	Panel = Color3.fromRGB(38, 42, 52),
	PanelAlt = Color3.fromRGB(49, 54, 66),
	Text = Color3.fromRGB(244, 246, 250),
	Muted = Color3.fromRGB(165, 173, 188),
	Accent = Color3.fromRGB(255, 214, 102),
	Error = Color3.fromRGB(255, 126, 95),
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

local function clearBuildRows()
	if buildList == nil then
		return
	end

	for _, child in ipairs(buildList:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function buildRow(summary: TBuildSummary)
	local onRestore = callbacks and callbacks.OnRestore
	local row = create("Frame", {
		BackgroundColor3 = COLORS.PanelAlt,
		Size = UDim2.new(1, -8, 0, 44),
		BorderSizePixel = 0,
	}, {
		create("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
	})

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -110, 0, 18),
		Font = Enum.Font.GothamBold,
		Text = summary.Title,
		TextColor3 = COLORS.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 22),
		Size = UDim2.new(1, -110, 0, 16),
		Font = Enum.Font.Gotham,
		Text = string.format("%d gates, %d wires", summary.GateCount, summary.WireCount),
		TextColor3 = COLORS.Muted,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local restoreButton = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(84, 28),
		BackgroundColor3 = COLORS.Accent,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "Restore",
		TextColor3 = Color3.fromRGB(34, 32, 27),
		TextSize = 12,
		Parent = row,
	}, {
		create("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
	}) :: TextButton

	restoreButton.MouseButton1Click:Connect(function()
		if onRestore then
			onRestore(summary.Title)
		end
	end)

	return row
end

function ClipboardUI.Open(newCallbacks: TCallbacks)
	ClipboardUI.Close()
	callbacks = newCallbacks

	activeGui = Instance.new("ScreenGui")
	activeGui.Name = "ClipboardGui"
	activeGui.ResetOnSpawn = false
	activeGui.Parent = Players.LocalPlayer.PlayerGui

	local panel = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 18, 0.5, 0),
		Size = UDim2.fromOffset(340, 360),
		BackgroundColor3 = COLORS.Background,
		BorderSizePixel = 0,
		Parent = activeGui,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 14) }),
		create("UIStroke", { Color = COLORS.PanelAlt, Thickness = 2 }),
	})

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 24),
		Font = Enum.Font.GothamBold,
		Text = "Clipboard",
		TextColor3 = COLORS.Text,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 38),
		Size = UDim2.new(1, -32, 0, 34),
		Font = Enum.Font.Gotham,
		Text = "Click once to place the first corner, click again to lock the box, then save it with a title.",
		TextColor3 = COLORS.Muted,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = panel,
	})

	titleBox = create("TextBox", {
		Position = UDim2.fromOffset(16, 82),
		Size = UDim2.new(1, -32, 0, 36),
		BackgroundColor3 = COLORS.Panel,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		PlaceholderText = "Save title",
		Text = "",
		TextColor3 = COLORS.Text,
		TextSize = 14,
		Parent = panel,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 10) }),
	}) :: TextBox

	local saveButton = create("TextButton", {
		Position = UDim2.fromOffset(16, 128),
		Size = UDim2.fromOffset(116, 34),
		BackgroundColor3 = COLORS.Accent,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "Save Box",
		TextColor3 = Color3.fromRGB(34, 32, 27),
		TextSize = 13,
		Parent = panel,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 10) }),
	}) :: TextButton
	saveButton.MouseButton1Click:Connect(function()
		local onSave = callbacks and callbacks.OnSave
		if onSave and titleBox then
			onSave(titleBox.Text)
		end
	end)

	local refreshButton = create("TextButton", {
		Position = UDim2.fromOffset(140, 128),
		Size = UDim2.fromOffset(86, 34),
		BackgroundColor3 = COLORS.Panel,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "Refresh",
		TextColor3 = COLORS.Text,
		TextSize = 13,
		Parent = panel,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 10) }),
	}) :: TextButton
	refreshButton.MouseButton1Click:Connect(function()
		local onRefresh = callbacks and callbacks.OnRefresh
		if onRefresh then
			onRefresh()
		end
	end)

	local resetButton = create("TextButton", {
		Position = UDim2.fromOffset(234, 128),
		Size = UDim2.fromOffset(90, 34),
		BackgroundColor3 = COLORS.Panel,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "Reset Box",
		TextColor3 = COLORS.Text,
		TextSize = 13,
		Parent = panel,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 10) }),
	}) :: TextButton
	resetButton.MouseButton1Click:Connect(function()
		local onReset = callbacks and callbacks.OnReset
		if onReset then
			onReset()
		end
	end)

	statusLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 172),
		Size = UDim2.new(1, -32, 0, 18),
		Font = Enum.Font.Gotham,
		Text = "Hover where you want to restore a saved build.",
		TextColor3 = COLORS.Muted,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	}) :: TextLabel

	buildList = create("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 196),
		Size = UDim2.new(1, -24, 1, -208),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = panel,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: ScrollingFrame
end

function ClipboardUI.SetBuilds(builds: { TBuildSummary })
	clearBuildRows()
	if buildList == nil then
		return
	end

	if #builds == 0 then
		create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -8, 0, 28),
			Font = Enum.Font.Gotham,
			Text = "No saved builds in this server yet.",
			TextColor3 = COLORS.Muted,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = buildList,
		})
		return
	end

	for _, summary in ipairs(builds) do
		buildRow(summary).Parent = buildList
	end
end

function ClipboardUI.SetStatus(text: string, isError: boolean?)
	if statusLabel == nil then
		return
	end

	statusLabel.Text = text
	statusLabel.TextColor3 = if isError then COLORS.Error else COLORS.Muted
end

function ClipboardUI.SetTitle(text: string)
	if titleBox then
		titleBox.Text = text
	end
end

function ClipboardUI.Close()
	if activeGui then
		activeGui:Destroy()
		activeGui = nil
	end

	titleBox = nil
	statusLabel = nil
	buildList = nil
	callbacks = nil
end

return ClipboardUI
