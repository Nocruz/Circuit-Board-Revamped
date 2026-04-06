return {
  Nodes = { Outputs = { "Output" }, Inputs = { "Input" } },
  DefaultVisuals = {
    MainColor = Color3.fromRGB(129, 20, 0)
  },
  
  Create = function(self, owner, model)
    local gate = setmetatable({}, { __index = self })
    gate.OwnerId = owner
    gate.Model = model
    return gate
  end,

  Process = function(self)
    return true
  end
}
