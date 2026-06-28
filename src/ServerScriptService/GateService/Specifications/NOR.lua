return {
  Nodes = { Outputs = { "Output" }, Inputs = { "A", "B" } },
  DefaultVisuals = { MainColor = Color3.fromRGB(164, 189, 71) },
  
  Process = function(self)
    self.Nodes.Signals["Output"] = not (self:ReadInput("A").AsBoolean() or self:ReadInput("B").AsBoolean())
  end
}
