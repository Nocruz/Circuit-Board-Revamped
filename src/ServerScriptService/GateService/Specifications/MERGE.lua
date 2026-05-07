local MAX_STRING_LENGTH = 100

return {
  Nodes = { Outputs = { "Output" }, Inputs = { "A", "B" } },
  DefaultVisuals = {
    MainMaterial = Enum.Material.Marble,
    MainColor = Color3.fromRGB(103, 0, 0)
  },
  
  Process = function(self)
    local A = self:ReadInput("A").AsString()
    A = if A == "false" then "" else A
    
    local B = self:ReadInput("B").AsString()
    B = if B == "false" then "" else B

    local Output = A .. B
    self.Nodes.Signals["Output"] = Output:sub(1, MAX_STRING_LENGTH)
  end
}
