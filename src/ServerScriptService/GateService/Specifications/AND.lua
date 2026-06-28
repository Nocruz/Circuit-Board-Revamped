return {
  Nodes = { Outputs = { "Output" }, Inputs = { "A", "B" } },
  DefaultVisuals = { MainColor = Color3.fromRGB(30, 100, 30) },
  
  Process = function(self)
    self.Nodes.Signals["Output"]  = self:ReadInput("A").AsBoolean() and self:ReadInput("B").AsBoolean()
  end
}
