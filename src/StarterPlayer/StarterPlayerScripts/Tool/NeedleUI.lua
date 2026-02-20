--!strict
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SetAttributeEvent = ReplicatedStorage.Client.Events:WaitForChild("Configure")
local MessageService = require(StarterPlayerScripts.Services.MessageService)

local NeedleUI = {}

local activeGui: ScreenGui?
local currentGateId: number?
local changesBuffer: { [string]: any } = {}

local COLORS = {
	Bg = Color3.fromRGB(40, 40, 45),
	Item = Color3.fromRGB(60, 60, 65),
	Text = Color3.fromRGB(240, 240, 240),
	Green = Color3.fromRGB(100, 255, 100),
	Red = Color3.fromRGB(255, 80, 80)
}

local function create(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props) do inst[k] = v end
	if children then for _, c in pairs(children) do c.Parent = inst end end
	return inst
end

function NeedleUI.Open(gateId: number, gateData: any)
	NeedleUI.Close()

	currentGateId = gateId
	changesBuffer = {}

	local schema = gateData.Schema
	local values = gateData.Values

	-- 1. Main Screen GUI
	activeGui = Instance.new("ScreenGui")
	activeGui.Name = "NeedleGUI"
	activeGui.ResetOnSpawn = false
	activeGui.Parent = Players.LocalPlayer.PlayerGui

	local blocker = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Parent = activeGui
	})
	blocker.MouseButton1Click:Connect(NeedleUI.Close)

	local container = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(300, 50),
		BackgroundColor3 = COLORS.Bg,
		BorderSizePixel = 0,
		Parent = activeGui
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 8) }),
		create("UIStroke", { Color = COLORS.Item, Thickness = 2 })
	})

	local topBar = create("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Parent = container
	}, {
		create("TextLabel", {
			Text = "Configuring Gate",
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = COLORS.Text,
			Size = UDim2.new(1, -30, 1, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 0),
			TextXAlignment = Enum.TextXAlignment.Left
		})
	})

	local closeBtn = create("TextButton", {
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -30, 0, 0),
		BackgroundTransparency = 1,
		Text = "P",
		TextColor3 = COLORS.Red,
		Font = Enum.Font.GothamBold,
		Parent = topBar
	})
	closeBtn.MouseButton1Click:Connect(NeedleUI.Close)

	local listLayout = create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5),
		HorizontalAlignment = Enum.HorizontalAlignment.Center
	})

	local content = create("Frame", {
		Position = UDim2.fromOffset(0, 35),
		Size = UDim2.new(1, 0, 0, 0), -- Auto size
		BackgroundTransparency = 1,
		Parent = container
	}, { listLayout })

	local totalHeight = 40

	for attrName, attrDef in pairs(schema) do
		local currentValue = values[attrName]
		if currentValue == nil then currentValue = attrDef.Default end

		local row = create("Frame", {
			Size = UDim2.new(0.9, 0, 0, 30),
			BackgroundColor3 = COLORS.Item,
			Parent = content
		}, { create("UICorner", { CornerRadius = UDim.new(0, 4) }) })

		-- Label
		create("TextLabel", {
			Text = attrName,
			Size = UDim2.new(0.5, -5, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			BackgroundTransparency = 1,
			TextColor3 = COLORS.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			Parent = row
		})

		-- Input Control
		local inputArea = create("Frame", {
			Size = UDim2.new(0.5, -5, 1, -4),
			Position = UDim2.new(0.5, 0, 0, 2),
			BackgroundTransparency = 1,
			Parent = row
		})

		if attrDef.Type == "boolean" or (attrDef.Allowed and #attrDef.Allowed > 0) then
			local btn = create("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = COLORS.Bg,
				TextColor3 = COLORS.Text,
				Text = tostring(currentValue),
				Font = Enum.Font.GothamBold,
				Parent = inputArea
			}, { create("UICorner", { CornerRadius = UDim.new(0, 4) }) })

			btn.MouseButton1Click:Connect(function()
				local newVal
				if attrDef.Type == "boolean" then
					newVal = not (changesBuffer[attrName] or currentValue)
				else
					-- Cycle logic
					local current = changesBuffer[attrName] or currentValue
					local idx = table.find(attrDef.Allowed, current) or 0
					idx = (idx % #attrDef.Allowed) + 1
					newVal = attrDef.Allowed[idx]
				end

				changesBuffer[attrName] = newVal
				btn.Text = tostring(newVal)
			end)

		else
			local box = create("TextBox", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = COLORS.Bg,
				TextColor3 = COLORS.Text,
				Text = tostring(currentValue),
				Font = Enum.Font.Code,
				ClearTextOnFocus = false,
				Parent = inputArea
			}, { create("UICorner", { CornerRadius = UDim.new(0, 4) }) })

			box.FocusLost:Connect(function()
				local text = box.Text
				local val = text

				if attrDef.Type == "number" then
					val = tonumber(text)
					if not val then 
						box.Text = tostring(currentValue) -- Revert invalid
						return 
					end
				end
				changesBuffer[attrName] = val
			end)
		end

		totalHeight += 35
	end

	container.Size = UDim2.fromOffset(300, totalHeight + 10)
end

function NeedleUI.Close()
	if not activeGui then return end

	if currentGateId and changesBuffer then
		for attr, val in pairs(changesBuffer) do
			task.spawn(function()
				local success, msg = SetAttributeEvent:InvokeServer(currentGateId, attr, val)
				if not success and msg then
					MessageService.SendMessage("Error on " .. attr .. ": " .. msg)
				end
			end)
		end
	end

	activeGui:Destroy()
	activeGui = nil
	currentGateId = nil
	changesBuffer = {}
end

return NeedleUI
