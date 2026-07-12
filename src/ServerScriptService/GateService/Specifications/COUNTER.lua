return {
	Nodes = { Outputs = { "Output" }, Inputs = { "Down", "Reset", "Up", "Delta", "ResetTo" } },
	DefaultVisuals = {
		MainMaterial = Enum.Material.DiamondPlate,
		MainColor = Color3.fromRGB(85, 45, 0)
	},
	
	AttributeData = {
		["Min"] = { Default = 0, Predicates = { } },
		["Max"] = { Default = 100, Predicates = { } },
		["Increment"] = { Default = 1, Predicates = { } },
		["ResetTo"] = { Default = 0, Predicates = { } },
	},
	
	Setup = function(self, state)
		if state.Internal then
			self.InternalState = {
				Count = if state.Internal.Count ~= nil then state.Internal.Count else 0,
				LastState = if state.Internal.LastState then state.Internal.LastState else { Down = false, Up = false }
			}
		else
			self.InternalState = {
				Count = 0,
				LastState = { Down = false, Up = false }
			}
		end
		
		self.Nodes.Signals["Output"] = self.InternalState.Count
	end,
	
	Process = function(self)
		local isUpPressed    = self:ReadInput("Up").AsBoolean()
		local isDownPressed  = self:ReadInput("Down").AsBoolean()
		local isResetPressed = self:ReadInput("Reset").AsBoolean()
		
		local hasIncrementConnection, increment = self:ReadAttributeFromNode("Increment", "Delta")
		increment = if hasIncrementConnection then increment.AsNumber() else increment
		local hasResetConnection, resetTo = self:ReadAttributeFromNode("ResetTo", "ResetTo")
		resetTo = if hasResetConnection then resetTo.AsNumber() else resetTo
		
		if isResetPressed then
			self.InternalState.Count = resetTo
		else
			if isUpPressed and not self.InternalState.LastState.Up then
				self.InternalState.Count += increment
			end
			if isDownPressed and not self.InternalState.LastState.Down then
				self.InternalState.Count -= increment
			end
		end
		
		local min = self.Attributes.Min
		local max = self.Attributes.Max
		if min > max then min, max = max, min end
		self.InternalState.Count = math.clamp(self.InternalState.Count, min, max)
		self.InternalState.LastState.Up   = isUpPressed
		self.InternalState.LastState.Down = isDownPressed
		self.Nodes.Signals["Output"] = self.InternalState.Count
	end
}
