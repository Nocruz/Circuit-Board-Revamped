return {
	Nodes = { Outputs = { "Output" }, Inputs = { "A", "B" } },
	DefaultVisuals = { 
		MainColor = Color3.fromRGB(116, 139, 87),
		DisplayName = "=="
	},
	
	Process = function(self)
		self.Nodes.Signals["Output"] = self:ReadInput("A").AsString() == self:ReadInput("B").AsString()
	end
}
