return {
	Nodes = { Outputs = { "Output" }, Inputs = { "A", "B" } },
	DefaultVisuals = { MainColor = Color3.fromRGB(29, 10, 170) },
	
	Process = function(self)
		self.Nodes.Signals["Output"] = self:ReadInput("A").AsBoolean() or self:ReadInput("B").AsBoolean()
	end
}
