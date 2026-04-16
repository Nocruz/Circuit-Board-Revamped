--!strict
--[[ SPECIFICATION TYPES
		Builders and authoring helpers for GateService specifications.
]]

--- Type definitions

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- -----------------------------

export type TAttributeSignalType = "number" | "string" | "boolean"

export type TSpecificationAttribute = {
	Default: any,
	Predicates: { (any) -> boolean },
	AllowedValues: { any }?,
	SignalType: TAttributeSignalType?,
}

export type TSpecificationNodes = {
	SignalInputs: { string },
	HasOutput: boolean,
}

export type TSpecificationSchema = {
	Name: string,
	Nodes: TSpecificationNodes,
	Attributes: { [string]: TSpecificationAttribute }?,
	DefaultVisuals: any,
	Create: ((gate: any) -> ())?,
	Process: (gate: any, origin: "Signal" | "Schedule") -> any,
	OnDestroy: ((gate: any) -> ())?,
	OnConnectionChanged: ((gate: any) -> ())?,
}

return {}
