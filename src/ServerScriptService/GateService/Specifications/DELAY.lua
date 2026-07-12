local ServerScriptService = game:GetService("ServerScriptService")
local Updates = require(ServerScriptService.GateService.Updates)

return {
	Nodes = { Outputs = { "Output" }, Inputs = { "Input" } },
	DefaultVisuals = {
		MainMaterial = Enum.Material.DiamondPlate,
		MainColor = Color3.fromRGB(153, 189, 189)
	},
	
	AttributeData = {
		["Delay"] = { Default = 1, Predicates = { function(value) return value >= 0 end, } },
	},
	
	Process = function(self, payload)
		local inputSignal = self:ReadInput("Input")
		local inputBool = inputSignal.AsBoolean()
		
		-- Rising edge: input goes from false -> true
		if inputBool and not self.Nodes.Signals["Output"] then
			if self.Attributes.Delay == 0 then
				self.Nodes.Signals["Output"] = inputSignal.Raw
			else
				if not Updates.IsWakeupScheduled(self.Id, "DelayTimer") then
					Updates.ScheduleWakeup(self.Id, self.Attributes.Delay, { Source = "DelayExpired" }, "DelayTimer")
				end
			end
			
		-- Input is true and was already true: update output instantly
		elseif inputBool and self.Nodes.Signals["Output"] then
			self.Nodes.Signals["Output"] = true
			
		-- Input turned false: cancel timers and output false immediately
		elseif not inputBool then
			Updates.CancelAllWakeups(self.Id)
			self.Nodes.Signals["Output"] = false
		end
		
		-- Handle delayed wakeup
		if payload and payload.Source == "DelayExpired" then
			-- After delay, output follows input (still true at this point)
			self.Nodes.Signals["Output"] = true
		end
	end
}
