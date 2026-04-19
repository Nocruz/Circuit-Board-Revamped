local Signals = require(script.Parent.Parent.Signals)

return {
  Nodes = { Outputs = { "Output" }, Inputs = { "A", "B" } },
  DefaultVisuals = {
    MainMaterial = Enum.Material.Marble,
    MainColor = Color3.fromRGB(103, 0, 0)
  },
  
  Process = function(self)
    local A = self:ReadInput("A").AsString()
    local B = self:ReadInput("B").AsString()

    self.Nodes.Signals["Output"] = Signals.EqualizeString((if A == "false" then "" else A) .. (if B == "false" then "" else B))
  end
}
