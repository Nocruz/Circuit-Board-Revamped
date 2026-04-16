--!strict
--[[ GATE SERVICE TYPES
		Shared public types for GateService.
]]

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- -----------------------------

export type TGateNodes = {
	SignalInputs: { string },
	AttributeInputs: { [string]: string },
	HasOutput: boolean,
	InputOrder: { string },
}

export type TGateSpecification = {
	Name: string,
	Nodes: TGateNodes,
	Attributes: { [string]: any },
	DefaultVisuals: any,
	Create: ((gate: TGateInstance) -> ())?,
	Process: (gate: TGateInstance, origin: "Signal" | "Schedule") -> any,
	OnDestroy: ((gate: TGateInstance) -> ())?,
	OnConnectionChanged: ((gate: TGateInstance) -> ())?,
}

export type TGateInstance = {
	Id: number,
	OwnerId: number,
	Specification: TGateSpecification,
	Model: Model,
	Output: any,
	Incoming: { [string]: { [TGateInstance]: true } },
	Outgoing: { [TGateInstance]: { [string]: { WireId: number? } } }?,
	Inputs: { [string]: { [TGateInstance]: true } },
	Connections: { [TGateInstance]: { [string]: { WireId: number? } } }?,
	Attributes: { [string]: any },
	State: { [string]: any },
	Destroyed: boolean?,
	Destroy: (self: TGateInstance) -> (),
	ConnectTo: (self: TGateInstance, target: TGateInstance, inputName: string) -> (boolean, string?),
	DisconnectFrom: (self: TGateInstance, target: TGateInstance, inputName: string) -> (boolean, string?),
	GetSignalInput: (self: TGateInstance, inputName: string) -> any,
	GetAttributeValue: (self: TGateInstance, attributeName: string) -> any,
	Schedule: (self: TGateInstance, delay: number) -> (),
	[string]: any,
}

export type TClipboardGate = {
	SpecificationName: string,
	Visuals: any,
	Attributes: { [string]: any },
	Offset: Vector3,
	Rotation: any,
}

export type TClipboardWire = {
	FromIndex: number,
	ToIndex: number,
	InputName: string,
}

export type TClipboardBuild = {
	Title: string,
	Gates: { TClipboardGate },
	Wires: { TClipboardWire },
	UpdatedAt: number,
}

export type TClipboardSummary = {
	Title: string,
	GateCount: number,
	WireCount: number,
	UpdatedAt: number,
}

return {}
