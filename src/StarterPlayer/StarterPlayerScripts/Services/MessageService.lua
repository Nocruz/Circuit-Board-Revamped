--[[ MESSAGE SERVICE
		Provides API to communicate with the user without checking logs.
]]

-- Requires and Services
local TweenService = game:GetService("TweenService")
local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

-- References
local messageGui = PlayerGui:WaitForChild("MessageGui")
local frame = messageGui:WaitForChild("Container")
local labelPrefab: TextLabel = messageGui:WaitForChild("FeedbackMessagePrefab")

-- Constants
local duration = 2 -- seconds
local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- ----------------------------- ----------- MODULE DEFINITION ----------- -----------------------------

local MessageService = {}

function MessageService.SendMessage(text)
	local label = labelPrefab:Clone()
	label.Text  = text
	label.Parent = frame
	
	local fadeIn  = TweenService:Create(label, tweenInfo, { TextTransparency = 0 })
	local fadeOut = TweenService:Create(label, tweenInfo, { TextTransparency = 1 })
	fadeIn.Completed:Connect(function() task.wait(duration); fadeOut:Play() end)
	fadeOut.Completed:Connect(function() label:Destroy() end)
	
	fadeIn:Play()
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return MessageService
