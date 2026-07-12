return {
	Nodes = { Outputs = { "Output" }, Inputs = { "Input", "Bridge" } },
	DefaultVisuals = {
		MainColor = Color3.fromRGB(0, 85, 0),
		InputOffsets = { Vector2.new(0.00, 0.50), Vector2.new(0.50, 0.00) }
	},
	
	Process = function(self)
		self.Nodes.Signals["Output"] = if self:ReadInput("Bridge").AsBoolean()
			then self:ReadInput("Input").Raw
			else ""
	end
}
