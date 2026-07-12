return {
	Nodes = { Outputs = { "Output" }, Inputs = { "Input", "Key", "Index" } },
	DefaultVisuals = {
		MainMaterial = Enum.Material.Marble,
		MainColor = Color3.fromRGB(35, 89, 95),
		InputOffsets = { Vector2.new(0.00, 0.50), Vector2.new(0.50, 0.25), Vector2.new(0.50, -0.15) }
	},
 
	AttributeData = {
	 ["Key"] = { Default = "", Predicates = { } },
	 ["Index"] = { Default = 0, Predicates = { function(value) return value >= 0 end } },
	},
 
	Process = function(self)
		local input = self:ReadInput("Input").AsString()
		local hasKeyConnection, key = self:ReadAttributeFromNode("Key", "Key")
		key = if hasKeyConnection then key.AsString() else key
		local hasIndexConnection, index = self:ReadAttributeFromNode("Index", "Index")
		index = math.floor(if hasIndexConnection then index.AsNumber() else index)
		-- Negative index -> ""
		if index < 0 then
			self.Nodes.Signals["Output"] = ""
			return
		end
		-- No key -> Consider entire string
		if key == "" then
			self.Nodes.Signals["Output"] = if index == 0 then input else ""
			return
		end
		-- Index == 0 -> Skip processing, return substring
		if index == 0 then
			local s = string.find(input, key, 1, true)
			self.Nodes.Signals["Output"] = if s then string.sub(input, 1, s - 1) else input
			return
		end
		-- Find the start position for the requested index lazily: Advance past index separators to reach the start, then find next separator for end.
		local startPos = 1
		local found = false
		for i = 1, index do
			local s, e = string.find(input, key, startPos, true)
			if not s then
				-- Fewer separators than needed -> index out of range
				self.Nodes.Signals["Output"] = ""
				return
			end
			startPos = e + 1
			found = true
		end
		if not found then
			self.Nodes.Signals["Output"] = ""
			return
		end
		-- find end of this element
		local s2 = string.find(input, key, startPos, true)
		if not s2 then
			-- last element
			self.Nodes.Signals["Output"] = string.sub(input, startPos)
		else
			self.Nodes.Signals["Output"] = string.sub(input, startPos, s2 - 1)
		end
	end
}
