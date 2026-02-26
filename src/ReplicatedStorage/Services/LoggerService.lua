--!strict
local LogService = {}

type LogFunction = (msg: string) -> ()
export type Logger = { info: LogFunction, warn: LogFunction, error: LogFunction }

local GLOBAL_DEBUG_ENABLED = true 
local IGNORED_TAGS: { [string]: boolean } = {
	-- Server
	["Bootstrap"] = true,
	["Spawn"] = true,
	["Move"] = true,
	["Wire"] = true,
	["UpdateManager"] = true,
	
	-- Shared
	["ClientRequestHandler"] = true,
	
	-- Client
	["PointerService"] = true,
	["BuildMode"] = true,
	["WireMode"] = true,
	["Pliers"] = true,
}

function LogService.new(tag: string): Logger
	local isIgnored = IGNORED_TAGS[tag] or false

	local function format(msg: string): string
		return string.format("[%s]: %s", tag, msg)
	end

	return {
		info = function(msg: string)
			if GLOBAL_DEBUG_ENABLED and not isIgnored then print(format(msg)) end
		end,

		warn = function(msg: string)
			warn(format(msg))
		end,

		error = function(msg: string)
			error(format(msg), 2)
			return
		end
	}
end

return LogService