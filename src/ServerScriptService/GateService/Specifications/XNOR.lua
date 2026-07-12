return {
	Nodes = { Outputs = { "Output" }, Inputs = { "A", "B" } },
	DefaultVisuals = { MainColor = Color3.fromRGB(0, 143, 156) },
	
	Process = function(self)
		self.Nodes.Signals["Output"] = self:ReadInput("A").AsBoolean() == self:ReadInput("B").AsBoolean()
	end
}
