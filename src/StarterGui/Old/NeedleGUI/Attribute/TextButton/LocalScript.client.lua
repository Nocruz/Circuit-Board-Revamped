local button = script.Parent

-- Optional: start with "false"
button.Text = "false"

button.MouseButton1Click:Connect(function()
	if button.Text == "true" then
		button.Text = "false"
	else
		button.Text = "true"
	end
end)