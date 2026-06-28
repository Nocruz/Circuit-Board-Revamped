return {
  Nodes = { Outputs = { "Output" }, Inputs = { "Input" } },
  DefaultVisuals = { 
    MainMaterial = Enum.Material.DiamondPlate,
    DisplayName = "SIN",
    MainColor = Color3.fromRGB(159, 161, 172)
  },
  
  Process = function(self)
    self.Nodes.Signals["Output"] = math.sin(self:ReadInput("Input").AsNumber())
  end
}
