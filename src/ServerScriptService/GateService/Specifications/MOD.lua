return {
  Nodes = { Outputs = { "Output" }, Inputs = { "A", "B" } },
  DefaultVisuals = { 
    MainMaterial = Enum.Material.DiamondPlate,
    MainColor = Color3.fromRGB(75, 27, 179)
  },
  
  Process = function(self)
    self.Nodes.Signals["Output"] = self:ReadInput("A").AsNumber() % self:ReadInput("B").AsNumber()
  end
}
