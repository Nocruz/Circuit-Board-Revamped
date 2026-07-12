local ServerScriptService = game:GetService("ServerScriptService")
local Updates = require(ServerScriptService.GateService.Updates)

return {
	Nodes = { Outputs = { }, Inputs = { "R", "G", "B" } },
	DefaultVisuals = {
		PrefabName = "Display",
		MainColor = Color3.fromRGB(91, 93, 105)
	},
	
	Setup = function(self, state)
		if state.Internal then
			self.InternalState = { Color = if state.Internal.Color ~= nil then state.Internal.Color else Color3.new() }
		else
			self.InternalState = { Color = Color3.new() }
		end
		
		Updates.RegisterVisualChange(self.Model.Screen, { Color = self.InternalState.Color })
	end,
	
	Process = function(self)
		self.InternalState.Color = Color3.new(self:ReadInput("R").AsNumber(), self:ReadInput("G").AsNumber(), self:ReadInput("B").AsNumber())
		Updates.RegisterVisualChange(self.Model.Screen, { Color = self.InternalState.Color })
	end
}
