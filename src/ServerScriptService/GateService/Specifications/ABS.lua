return {
  Nodes = { Outputs = { "Output" }, Inputs = { "Input" } },
  DefaultVisuals = { 
    MainMaterial = Enum.Material.DiamondPlate,
    MainColor = Color3.fromRGB(75, 27, 179)
  },
  
  Process = function(self)
    self.Nodes.Signals["Output"] = math.abs(self:ReadInput("Input").AsNumber())
  end
}
