local StarterGui = game:GetService("StarterGui")

while not pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", false) do
	task.wait(1)
end