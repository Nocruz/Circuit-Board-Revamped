local ServerScriptService = game:GetService("ServerScriptService")
local Updates = require(ServerScriptService.GateService.Updates)

return {
	Nodes = { Outputs = { "Output" }, Inputs = { "Input" } },
	DefaultVisuals = {
		MainMaterial = Enum.Material.DiamondPlate,
		MainColor = Color3.fromRGB(153, 189, 189)
	},
	
	AttributeData = {
		["Delay"] = { Default = 1, Predicates = { function(value) return value >= 0.1 end, } },
		["Duration"] = { Default = 1, Predicates = { function(value) return value >= 0.1 end, } },
	},
	
	Setup = function(self)
		if self.Nodes.Signals["Output"] then
			if not Updates.IsWakeupScheduled(self.ID, "DelayTimer") then
				Updates.ScheduleWakeup(self.ID, self.Attributes.Delay, { Source = "DelayExpired" }, "DelayTimer")
			end
		end
	end,
	
	Process = function(self, payload)
		local inputSignal = self:ReadInput("Input")
		local inputBool = inputSignal.AsBoolean()
		
		-- Rising edge: input goes from false -> true
		if inputBool and not self.Nodes.Signals["Output"] then
			if not Updates.IsWakeupScheduled(self.ID, "DelayTimer") then
				Updates.ScheduleWakeup(self.ID, self.Attributes.Delay, { Source = "DelayExpired" }, "DelayTimer")
			end
		-- Input turned false before gate turned on: cancel timer and output false immediately
		elseif not inputBool then
			Updates.CancelAllWakeups(self.ID)
			self.Nodes.Signals["Output"] = false
		end
		
		-- Handle delayed wakeup
		if payload and payload.Source == "DelayExpired" then
			self.Nodes.Signals["Output"] = true
			if not Updates.IsWakeupScheduled(self.ID, "DurationTimer") then
				Updates.ScheduleWakeup(self.ID, self.Attributes.Duration, { Source = "DurationExpired" }, "DurationExpired")
			end
		elseif payload and payload.Source == "DurationExpired" then
			self.Nodes.Signals["Output"] = false
			if inputBool and not self.Nodes.Signals["Output"] then
				if not Updates.IsWakeupScheduled(self.ID, "DelayTimer") then
					Updates.ScheduleWakeup(self.ID, self.Attributes.Delay, { Source = "DelayExpired" }, "DelayTimer")
				end
			end
		end
	end,
	
	Destroy = function(self)
		Updates.CancelAllWakeups(self.ID)
	end
}
