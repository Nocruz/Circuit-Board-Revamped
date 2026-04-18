return {
  Nodes = { Outputs = { "Output" }, Inputs = { "A", "B" } },
  DefaultVisuals = {
    MainMaterial = Enum.Material.Marble,
    MainColor = Color3.fromRGB(103, 0, 0)
  },
  
  Process = function(self)
    local A = self:ReadInput("A")
    local B = self:ReadInput("B")
    self.Nodes.Signals["Output"] = (if A.AsBoolean() then A.AsString() else "") .. (if B.AsBoolean() then B.AsString() else "")
  end
}
