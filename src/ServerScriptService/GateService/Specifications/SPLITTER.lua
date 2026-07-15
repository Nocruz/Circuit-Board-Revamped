return {
	Nodes = { Outputs = { "1", "2", "3", "4", "5", "6", "7", "8" }, Inputs = { "Input" } },
	DefaultVisuals = {
		MainColor = Color3.fromRGB(10, 20, 50),
		PrefabName = "Wide",
		
		OutputOffsets = { Vector2.new(-0.39, -0.50), Vector2.new(-0.28, -0.50), Vector2.new(-0.17, -0.50), Vector2.new(-0.06, -0.50), Vector2.new(0.06, -0.50), Vector2.new(0.17, -0.50), Vector2.new(0.28, -0.50), Vector2.new(0.39, -0.50) }
	},
	
	AttributeData = {
		["Endian"] = { Default = "Little", Predicates = { }, AllowedValues = { "Little", "Big" } }
	},
	
	Process = function(self)
		local input = math.floor(self:ReadInput("Input").AsNumber())
		local endian = self.Attributes.Endian

		for i = 0, 7 do
			local bit = bit32.extract(input, i)

			if endian == "Little" then
				self.Nodes.Signals[tostring(i + 1)] = bit
			else
				self.Nodes.Signals[tostring(8 - i)] = bit
			end
		end
	end
}
