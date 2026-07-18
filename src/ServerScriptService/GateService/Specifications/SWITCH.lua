local ServerScriptService = game:GetService("ServerScriptService")
local Updates = require(ServerScriptService.GateService.Updates)

return {
	Nodes = { Outputs = { "Output" }, Inputs = { "Toggle" } },
	DefaultVisuals = {
		PrefabName = "Switch",
		MainColor = Color3.fromRGB(255, 140, 10)
	},
	
	AttributeData = {
		["IsClickable"] = { Default = true, Predicates = { } },
	},
	
	Setup = function(self, state)
		if state.Internal then
			self.InternalState = {
				IsActivated = if state.Internal.IsActivated ~= nil then state.Internal.IsActivated else false,
				LastInput = if state.Internal.LastInput ~= nil then state.Internal.LastInput else false
			}
		else
			self.InternalState = { IsActivated = false, LastInput = false }
		end
		
		self.SWITCH = {}
		self.SWITCH.Weld = self.Model.Main.Weld
		self.SWITCH.ClickDetector = if self.OwnerID ~= 0
			then (function() local c = Instance.new("ClickDetector"); c.Parent = self.Model; return c end)()
			else nil
		self.SWITCH.ClickDetectorConnection = if self.OwnerID ~= 0
			then self.SWITCH.ClickDetector.MouseClick:Connect(function(player) Updates.Propagate(self.ID, { Source = "Interaction", Player = player }) end)
			else nil
		
		local offset = if self.InternalState.IsActivated then 0.5 else 0.75
		self.SWITCH.Weld.C1 = CFrame.new(0, offset, 0)
	end,
	
	Process = function(self, payload)
		if payload and payload.Source == "Interaction" and self.Attributes.IsClickable then
			self.InternalState.IsActivated = not self.InternalState.IsActivated
		
		else
			local input = self:ReadInput("Toggle").AsBoolean()
			if input and not self.InternalState.LastInput then
				self.InternalState.IsActivated = not self.InternalState.IsActivated
			end
			self.InternalState.LastInput = input
		end
		local height = if self.InternalState.IsActivated then 0.5 else 0.75
		self.SWITCH.Weld.C1 = CFrame.new(0, height, 0)
		self.Nodes.Signals["Output"] = self.InternalState.IsActivated
		
		if self.Nodes.Signals["Output"] then
			self:QueueSound("Activate Activator")
		else
			self:QueueSound("Deactivate Activator")
		end
	end,
	
	Destroy = function(self)
		if self.SWITCH.ClickDetectorConnection then
			self.SWITCH.ClickDetectorConnection:Disconnect()
			self.SWITCH.ClickDetectorConnection = nil
		end
	end
}
