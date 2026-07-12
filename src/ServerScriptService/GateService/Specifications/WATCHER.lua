local ServerScriptService = game:GetService("ServerScriptService")
local Updates = require(ServerScriptService.GateService.Updates)

return {
	Nodes = { Outputs = { "Output" }, Inputs = { "Input" } },
	DefaultVisuals = {
		MainMaterial = Enum.Material.Sand,
		MainColor = Color3.fromRGB(60, 60, 60),
	},
	
	Setup = function(self, state)
		if state.Internal then
			self.InternalState = {
				PulseActive = if state.Internal.PulseActive ~= nil then state.Internal.PulseActive else false,
				LastInput = if state.Internal.LastInput ~= nil then state.Internal.LastInput else false
			}
			
		else
			self.InternalState = {
				PulseActive = false,
				LastInput = false
			}
		end
	end,
	
	Process = function(self, payload)
		local input = self:ReadInput("Input")
		local current = input.Raw
		
		if payload and payload.Source == "ResetPulse" then
			self.InternalState.PulseActive = false
			self.Nodes.Signals["Output"] = false
			return
		end
		
		if self.InternalState.LastInput == nil then
			self.InternalState.LastInput = current
			self.Nodes.Signals["Output"] = false
			return
		end
		
		if current ~= self.InternalState.LastInput then
			self.InternalState.LastInput = current
			self.InternalState.PulseActive = true
			self.Nodes.Signals["Output"] = true
			Updates.ScheduleWakeup(self.ID, 0, { Source = "ResetPulse" }, "ResetPulse")
			return
		end
		
		self.Nodes.Signals["Output"] = self.InternalState.PulseActive
	end,
}
