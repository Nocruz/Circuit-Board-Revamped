return {
	Nodes = { Outputs = { "Output" }, Inputs = { "Input", "Bridge" } },
	DefaultVisuals = {
		MainColor = Color3.fromRGB(232, 174, 0),
		InputOffsets = { Vector2.new(0.00, 0.50), Vector2.new(0.50, 0.00) }
	},
	
	Setup = function(self, state)
		if state.Internal then
			self.InternalState = { Value = if state.Internal.Value ~= nil then state.Internal.Value else false }
		else
			self.InternalState = { Value = false }
		end
		
		self.Nodes.Signals["Output"] = self.InternalState.Value
	end,
	
	Process = function(self)
		self.InternalState.Value = if self:ReadInput("Bridge").AsBoolean()
			then self:ReadInput("Input").Raw
			else self.Nodes.Signals["Output"]
		
		self.Nodes.Signals["Output"] = self.InternalState.Value
	end
}
