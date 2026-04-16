return {
  Nodes = { Outputs = { "Output" }, Inputs = { "Input", "Tens" } },
  DefaultVisuals = {
    MainColor = Color3.fromRGB(189, 195, 68),
    MainMaterial = Enum.Material.DiamondPlate,
    InputOffsets = { Vector2.new(0.00, 0.50), Vector2.new(0.50, 0.00) }
  },
  AttributeData = {
    ["Strategy"] = { Default = "Closest", Predicates = { }, AllowedValues = { "Closest", "Floor", "Ceil" } },
    ["Tens"] = { Default = 0, Predicates = { function(value) return value % 1 == 0 end} },
  },

  Process = function(self)
    local input = self:ReadInput("Input").AsNumber()
    local hasConnection, tens = self:ReadAttribute("Tens", "Tens")
    tens = if hasConnection then tens.AsNumber() else tens
    local strategy = self.Attributes.Strategy

  	local factor = 10 ^ (-tens)
  	local scaledInput = input * factor

  	local roundedValue
  	if strategy == "Floor" then roundedValue = math.floor(scaledInput)
  	elseif strategy == "Ceil" then roundedValue = math.ceil(scaledInput)
  	else roundedValue = math.round(scaledInput)
  	end

  	self.Nodes.Signals["Output"] = roundedValue / factor
	end
}
