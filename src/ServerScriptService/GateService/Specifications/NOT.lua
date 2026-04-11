return {
  Nodes = { Outputs = { "Output" }, Inputs = { "Input" } },
  DefaultVisuals = { MainColor = Color3.fromRGB(129, 20, 0) },
  
  Process = function(self)
    self.Nodes.Signals["Output"] = not self:ReadInput("Input").AsBoolean()
  end
}
