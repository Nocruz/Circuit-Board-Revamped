--!strict
--[[ SIGNAL SERVICE
		Global methods and definitions for handling signals
		A signal is the data type Gates output
		
		Signals are coded this way so multiple versions of the "same" value
		  have the same result in game.
		This way, a string signal will never have a numeric value, because if it has,
		  will be converted to a numeric signal. That's why a boolean output will
		  show as "true" on a DISPLAY.
]]

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")

-- ----------------------------- ---------- TYPE DEFINITIONS ---------- ---------------------------

local Types = require(ServerScriptService.Gates.Definitions.Types)
export type TSignal = Types.TSignal

-- ----------------------------- ----------- HELPER METHODS ----------- ---------------------------

-- For string to number formatting
local function isScientificNotation(s: string): boolean return s:match("^[+-]?%d+%.?%d*[eE][+-]?%d+$") ~= nil end

-- ----------------------------- --------- GLOBALS DEFINITION --------- ---------------------------

local SignalService = {}

-- ----------------------------- ------------- CASTING ---------------- -----------------------------

function SignalService.toBoolean(signal: TSignal): boolean
	if type(signal) == "boolean" then return signal end
	if type(signal) == "number" then return signal ~= 0 end
	if type(signal) == "string" then return signal ~= "" and signal ~= "0" and signal:lower() ~= "false" end

	warn("Invalid signal type. Must be string, number, or boolean.")
	return false
end

function SignalService.toNumber(signal: TSignal): number
	if type(signal) == "boolean" then return if signal then 1 else 0 end
	if type(signal) == "number" then return signal end
	if type(signal) == "string" then return tonumber(signal) or #signal end

	warn("Invalid signal type. Must be string, number, or boolean.")
	return 0
end

function SignalService.toString(signal: TSignal): string
	local result = ""
	if type(signal) == "string" then result = signal end
	if tostring(signal) then result = tostring(signal) end
	
	return result
end

-- ----------------------------- ----------- SIGNAL CREATION ---------- ---------------------------

function SignalService.normalize(value: any): TSignal
	if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
		if type(value) == "string" then
			local num = tonumber(value)
			if num and (tostring(num) == value or isScientificNotation(value)) then return num end
			if value:lower() == "true"  then return true  end
			if value:lower() == "false" then return false end
		end
		return value
	end
	
	return false
end

-- ----------------------------- ------------ COMPARISONS ------------- -----------------------------

function SignalService.equals(p1: TSignal, p2: TSignal): boolean
	if type(p1) == type(p2) then return p1 == p2 end
	return SignalService.toNumber(p1) == SignalService.toNumber(p2)
end

function SignalService.isGreater(p1: TSignal, p2: TSignal): boolean
	return SignalService.toNumber(p1) > SignalService.toNumber(p2)
end

-- ----------------------------- ----------- END OF MODULE ------------ -----------------------------

return SignalService