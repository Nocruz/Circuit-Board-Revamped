return {
  Nodes = { Outputs = { "Output" }, Inputs = { "A", "B" } },
  DefaultVisuals = { MainColor = Color3.fromRGB(188, 96, 4) },
  
  Process = function(self)
    self.Nodes.Signals["Output"] = not (self:ReadInput("A").AsBoolean() and self:ReadInput("B").AsBoolean())
  end
}
