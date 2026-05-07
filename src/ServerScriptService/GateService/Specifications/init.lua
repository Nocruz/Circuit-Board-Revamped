--!strict

local numberToSpec = {
	"ABS",
	"ADD",
	"AND",
	"BUTTON",
	"CLAMP",
	"CLOCK",
	"COSINE",
	"COUNTER",
	"DELAY",
	"DISPLAY",
	"DIVIDE",
	"EQUALS",
	"FIND",
	"GREATER",
	"KEY",
	"LATCH",
	"LENGTH",
	"LESSER",
	"LIGHT",
	"MERGE",
	"MOD",
	"MULTIPLY",
	"NAND",
	"NODE",
	"NOR",
	"NOT",
	"OR",
	"PIXEL",
	"POWER",
	"RANDOM",
	"ROOT",
	"ROUND",
	"SINE",
	"SUBSET",
	"SUBTRACT",
	"SWITCH",
	"TANGENT",
	"TIMER",
	"TRANSISTOR",
	"UNEQUALS",
	"VALUE",
	"WATCHER",
	"XNOR",
	"XOR",
}

local specToNumber = {}
for number, specificationName in ipairs(numberToSpec) do
	specToNumber[specificationName] = number
end

return {
	specToNumber = specToNumber,
	numberToSpec = numberToSpec,
}
