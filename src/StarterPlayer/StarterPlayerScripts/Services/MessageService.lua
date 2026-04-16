local MessageService = {}

local TweenService = game:GetService("TweenService")
local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

-- Ensure these names match your UI hierarchy
local screenGui = PlayerGui:WaitForChild("OLD"):WaitForChild("MessageGui")
local container = screenGui:WaitForChild("Container")

function MessageService.SendMessage(text)
	-- Create the Label
	local label = Instance.new("TextLabel")
	label.Name = "FeedbackMessage"
	label.Size = UDim2.new(1, 0, 0, 30)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(218, 13, 6)
	label.TextSize = 24
	label.Font = Enum.Font.BuilderSansBold -- Modern Roblox font
	label.Parent = container

	-- Setup Tween
	local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local fade = TweenService:Create(label, tweenInfo, {TextTransparency = 1})

	-- Lifecycle: Show for 1 second, then fade for 1 second, then destroy
	task.delay(1, function()
		fade:Play()
		fade.Completed:Connect(function()
			label:Destroy()
		end)
	end)
end

return MessageService
