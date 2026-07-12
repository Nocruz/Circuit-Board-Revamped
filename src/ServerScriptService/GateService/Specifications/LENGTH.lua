return {
	Nodes = { Outputs = { "Output" }, Inputs = { "Input" } },
	DefaultVisuals = {
		MainMaterial = Enum.Material.Marble,
		MainColor = Color3.fromRGB(52, 142, 64)
	},
	
	Process = function(self)
		local input = self:ReadInput("Input")
		self.Nodes.Signals["Output"] = if input.AsBoolean() then input.AsString():len() else 0
	end
}
