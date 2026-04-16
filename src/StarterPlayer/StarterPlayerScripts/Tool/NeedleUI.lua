--!strict
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Types from your specification
export type Predicate<T> = (value: T) -> (boolean, string?)

export type TAttributeSpecification<T> = {
	Default: T,
	Predicates: { Predicate<T> },
	AllowedValues: { T }?,
}

local SetAttributeEvent = ReplicatedStorage.Client.Events:WaitForChild("Configure")
local MessageService = require(StarterPlayerScripts.Services.MessageService)

local NeedleUI = {}

local activeGui: ScreenGui?
local currentGateId: string? -- Changed to string to match common ID types
local changesBuffer: { [string]: any } = {}
local schemaBuffer: { [string]: TAttributeSpecification<any> } = {}

local COLORS = {
	Bg = Color3.fromRGB(30, 30, 35),
	Item = Color3.fromRGB(45, 45, 50),
	Input = Color3.fromRGB(20, 20, 25),
	Text = Color3.fromRGB(230, 230, 230),
	Accent = Color3.fromRGB(0, 170, 255),
	Error = Color3.fromRGB(255, 80, 80)
}

-- Helper for clean instance creation
local function create<T>(className: string, props: { [string]: any }, children: { Instance }?): T
	local inst = Instance.new(className)
	for k, v in pairs(props) do (inst :: any)[k] = v end
	if children then 
		for _, c in ipairs(children) do c.Parent = inst end 
	end
	return inst :: any
end

-- Validation logic using your Predicates
local function validate(attrName: string, value: any): (boolean, string?)
	local spec = schemaBuffer[attrName]
	if not spec then return true end
	
	for _, predicate in ipairs(spec.Predicates) do
		local success, errorMsg = predicate(value)
		if not success then return false, errorMsg end
	end
	return true
end

function NeedleUI.Open(gateId: string, schema: { [string]: TAttributeSpecification<any> }, currentValues: { [string]: any })
	NeedleUI.Close() -- Safety cleanup

	currentGateId = gateId
	changesBuffer = {}
	schemaBuffer = schema

	activeGui = create("ScreenGui", {
		Name = "NeedleGUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	})

	-- Background Dimmer/Blocker
	local blocker = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0.5,
		BackgroundColor3 = Color3.new(0,0,0),
		Text = "",
		Parent = activeGui
	})
	blocker.MouseButton1Click:Connect(NeedleUI.Close)

	local container = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(350, 40), -- Height adjusts dynamically
		BackgroundColor3 = COLORS.Bg,
		BorderSizePixel = 0,
		Parent = activeGui
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 6) }),
		create("UIStroke", { Color = COLORS.Item, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	})

	local listLayout = create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center
	})
	
	local content = create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -20),
		Position = UDim2.fromOffset(0, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		Parent = container
	}, { 
		listLayout,
		create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) })
	})

	local rowCount = 0

	for attrName, spec in pairs(schema) do
		rowCount += 1
		local value = currentValues[attrName]
		if value == nil then value = spec.Default end

		local row = create("Frame", {
			Size = UDim2.new(0.9, 0, 0, 35),
			BackgroundColor3 = COLORS.Item,
			LayoutOrder = rowCount,
			Parent = content
		}, { create("UICorner", { CornerRadius = UDim.new(0, 4) }) })

		create("TextLabel", {
			Text = attrName,
			Size = UDim2.new(0.4, 0, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			BackgroundTransparency = 1,
			TextColor3 = COLORS.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			Parent = row
		})

		local inputContainer = create("Frame", {
			Size = UDim2.new(0.55, -10, 0.8, 0),
			Position = UDim2.new(1, -5, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			Parent = row
		})

		-- TYPE LOGIC: AllowedValues (Cycle) vs Boolean (Toggle) vs Text/Number (Input)
		if spec.AllowedValues and #spec.AllowedValues > 0 then
			local btn = create("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = COLORS.Input,
				TextColor3 = COLORS.Accent,
				Text = tostring(value),
				Font = Enum.Font.GothamBold,
				Parent = inputContainer
			}, { create("UICorner", { CornerRadius = UDim.new(0, 4) }) })

			btn.MouseButton1Click:Connect(function()
				local current = changesBuffer[attrName] or value
				local idx = table.find(spec.AllowedValues :: {any}, current) or 0
				local nextVal = spec.AllowedValues[(idx % #spec.AllowedValues) + 1]
				
				changesBuffer[attrName] = nextVal
				btn.Text = tostring(nextVal)
			end)

		elseif typeof(spec.Default) == "boolean" then
			local btn = create("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = COLORS.Input,
				TextColor3 = if value then COLORS.Accent else COLORS.Text,
				Text = if value then "TRUE" else "FALSE",
				Font = Enum.Font.GothamBold,
				Parent = inputContainer
			}, { create("UICorner", { CornerRadius = UDim.new(0, 4) }) })

			btn.MouseButton1Click:Connect(function()
				local current = if changesBuffer[attrName] ~= nil then changesBuffer[attrName] else value
				local nextVal = not current
				changesBuffer[attrName] = nextVal
				btn.Text = if nextVal then "TRUE" else "FALSE"
				btn.TextColor3 = if nextVal then COLORS.Accent else COLORS.Text
			end)

		else
			local box = create("TextBox", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = COLORS.Input,
				TextColor3 = COLORS.Text,
				Text = tostring(value),
				Font = Enum.Font.Code,
				TextSize = 12,
				ClearTextOnFocus = false,
				Parent = inputContainer
			}, { create("UICorner", { CornerRadius = UDim.new(0, 4) }) })

			box.FocusLost:Connect(function()
				local text = box.Text
				local castedValue: any = text
				
				if typeof(spec.Default) == "number" then
					castedValue = tonumber(text)
				end

				local isValid, errorMsg = validate(attrName, castedValue)
				if isValid and castedValue ~= nil then
					changesBuffer[attrName] = castedValue
					box.TextColor3 = COLORS.Text
				else
					box.Text = tostring(value) -- Revert
					box.TextColor3 = COLORS.Error
					if errorMsg then MessageService.SendMessage(errorMsg) end
				end
			end)
		end
	end

	-- Dynamically resize container based on rows (max height 400)
	local finalHeight = math.min(450, (rowCount * 43) + 40)
	container.Size = UDim2.fromOffset(350, finalHeight)
end

function NeedleUI.Close()
	if not activeGui or not currentGateId then return end

	-- Apply all changes buffered in the session
	for attr, val in pairs(changesBuffer) do
		-- Using task.spawn so one failing remote call doesn't hang the loop
		task.spawn(function()
			local success, msg = SetAttributeEvent:InvokeServer(currentGateId, attr, val)
			if not success and msg then
				MessageService.SendMessage(`Failed to set {attr}: {msg}`)
			end
		end)
	end

	activeGui:Destroy()
	activeGui = nil
	currentGateId = nil
	table.clear(changesBuffer)
	table.clear(schemaBuffer)
end

return NeedleUI
