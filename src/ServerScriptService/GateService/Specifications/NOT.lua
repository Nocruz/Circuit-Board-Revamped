return {
  Nodes = { Outputs = { "Output" }, Inputs = { "Input" } },
  DefaultVisuals = { MainColor = Color3.fromRGB(129, 20, 0) },
  
  Create = function(self, owner, model)
    local gate = setmetatable({}, { __index = self })
    gate.OwnerId = owner
    gate.Model = model
    
    gate.Nodes = { Outputs = {}, Inputs = {} }
    for _, output in ipairs(self.Nodes.Outputs) do gate.Nodes.Outputs[output] = { } end
    for _, input in ipairs(self.Nodes.Inputs) do gate.Nodes.Inputs[input] = { } end
        
    return gate
  end,

  Process = function(self)
    return true
  end
}
