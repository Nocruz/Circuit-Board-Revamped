local ClickDetector = script.Parent.ClickDetector

local LEFT = script.Parent.Decoration.LEFT
local RIGHT = script.Parent.Decoration.RIGHT

local state = 1

ClickDetector.MouseClick:Connect(function()
	if state == 1 then
		print("state 1")
		LEFT:PivotTo(LEFT:GetPivot():ToWorldSpace(CFrame.Angles(0, math.rad(90), 0)))
		RIGHT:PivotTo(RIGHT:GetPivot():ToWorldSpace(CFrame.Angles(0, math.rad(-90), 0)))
		state = 2
	elseif state == 2 then
		print("state 2")
		LEFT:PivotTo(LEFT:GetPivot():ToWorldSpace(CFrame.Angles(0, math.rad(-90), 0)))
		RIGHT:PivotTo(RIGHT:GetPivot():ToWorldSpace(CFrame.Angles(0, math.rad(90), 0)))
		state = 1
	end
end)