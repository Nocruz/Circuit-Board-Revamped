--[[ SIGNALS
		Global methods and definitions for handling signals.
		A signal represents the information in wires.
		
		Signals are coded this way so multiple versions of the "same" value
		have the same result in game.
		
		This way, a 'string' signal will never have a 'numeric' value, because if it has,
		will be converted to a numeric signal. That's why a boolean output will
		show as "true" on a DISPLAY, even if the input was actually "TRUE"
]]

-- ----------------------------- ---------- TYPE DEFINITIONS ---------- ---------------------------

export type TSignal = (string | number | boolean)

-- ----------------------------- --------- GLOBALS DEFINITION --------- ---------------------------

local Signals = {}

-- ----------------------------- ------------- CASTING ---------------- -----------------------------

function Signals.toBoolean(signal: TSignal): boolean
	if type(signal) == "boolean" then return signal end
	if type(signal) == "number"  then return signal ~= 0 end
	if type(signal) == "string"  then return signal ~= "" and signal ~= "0" and signal ~= "false" end
	
	error("Invalid signal type. Must be string, number, or boolean.")
end

function Signals.toNumber(signal: TSignal): number
	if type(signal) == "boolean" then return if signal then 1 else 0 end
	if type(signal) == "number"  then return signal end
	if type(signal) == "string"  then return tonumber(signal) or (signal == "false" and 0) or (signal == "true" and 1) or #signal end
	
	error("Invalid signal type. Must be string, number, or boolean.")
end

function Signals.toString(signal: TSignal): string
	return tostring(signal)
end

-- ----------------------------- ------------ COMPARISONS ------------- -----------------------------

function Signals.EqualizeString(str: TSignal): TSignal
	if type(str) == "string" then
		if str == "false" or str == "" then return false end
		if str == "true" then return true end
		local num = tonumber(str)
		if num and tostring(num) == str then return num end
	end
	return str
end


-- Should work. Probably
function Signals.equals(p1: TSignal, p2: TSignal): boolean
	if type(p1) == type(p2) then return p1 == p2 end
	return Signals.toString(p1) == Signals.toString(p2)
end

-- A signal is as strong as the amount of information it holds (Probably)
-- This function should only be used to collapse a set of signals
-- 1. Strings are always stronger.
-- 2. Longer strings are strongest.
-- 3. A number is as strong as its opposite
-- 4. True == 1, False == 0
function Signals.isStronger(s1: TSignal, s2: TSignal): boolean
	s1 = Signals.EqualizeString(s1)
	s2 = Signals.EqualizeString(s2)
	
	if type(s1) == "string" and type(s2) == "string" then return #s1 > #s2 end
	if type(s1) == "string" and type(s2) ~= "string" then return true end
	if type(s1) ~= "string" and type(s2) == "string" then return false end

	local s1Value = math.abs(Signals.toNumber(s1))
	local s2Value = math.abs(Signals.toNumber(s2))

	return s1Value > s2Value
end

-- ----------------------------- ------------ COLLECTIONS ------------- -----------------------------

function Signals.Collapse(collection: { TSignal }): TSignal
	if next(collection) == nil then return false end
	local strongest: TSignal?
	
	for _, signal in ipairs(collection) do
		if strongest == nil or Signals.isStronger(signal, strongest) then
			strongest = signal
		end
	end

	return strongest :: TSignal
end

-- ----------------------------- ----------- END OF MODULE ------------ -----------------------------

return Signals
