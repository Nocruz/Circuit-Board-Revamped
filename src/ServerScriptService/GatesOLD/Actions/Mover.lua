--!strict
--[[ MOVER
		Moves around gate instances.
]]

local Mover = {}

-- ----------------------------- ----------- HELPER METHODS ----------- ---------------------------

-- ----------------------------- ------------- MOVE GATE -------------- ---------------------------

function Mover.Move(gate: Model, cframe: CFrame)
	gate:PivotTo(cframe)
end

-- ----------------------------- ----------- END OF MODULE ------------ -----------------------------

return Mover
