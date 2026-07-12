local ServerScriptService = game:GetService("ServerScriptService")
local Updates = require(ServerScriptService.GateService.Updates)

return {
	Nodes = { Outputs = { }, Inputs = { "Input" } },
	DefaultVisuals = {
		PrefabName = "Display",
		MainColor = Color3.fromRGB(91, 93, 105)
	},
	
	AttributeData = {
		["Text"] = { Default = "", Predicates = { } }
	},
	
	Setup = function(self, state)
		if state.Internal then
			self.InternalState = { Text = if state.Internal.Text ~= nil then state.Internal.Text else "" }
		else
			self.InternalState = { Text = "" }
		end
		
		self.DISPLAY = { Label = self.Model.Screen.SurfaceGui.TextLabel }
		Updates.RegisterVisualChange(self.DISPLAY.Label, { Text = if self.InternalState.Text == "false" then "" elseif self.InternalState.Text == "true" then 1 else self.InternalState.Text })
	end,
	
	Process = function(self)
		local hasInputConnection, value = self:ReadAttributeFromNode("Text", "Input")
		self.InternalState.Text = if hasInputConnection then value.AsString() else value
		
		Updates.RegisterVisualChange(self.DISPLAY.Label, { Text = if self.InternalState.Text == "false" then "" elseif self.InternalState.Text == "true" then 1 else self.InternalState.Text })
	end
}
