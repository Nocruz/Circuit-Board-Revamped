--!strict
--[[ NODE
		Shared definitions and helpers for gate node collections.

		A node is a set of gates keyed by the gate instance itself.
		This lets us test membership and disconnect in O(1) without
		having to translate through gate IDs first.
]]

-- Requires and Services
-- ----------------------------- ---------- TYPE DEFINITIONS ----------- -----------------------------

type TGate = any

export type TNode = { [TGate]: true }
export type TNodes = { [string]: TNode }

export type TNodeConnection = {
	existance: true,
	Wire: number?,
}

export type TNodeConnections = { [TGate]: { [string]: TNodeConnection } }

export type TNodeInformation = {
	HasOutput: boolean,
	InputCount: number,
	Inputs: { string },
}

-- ----------------------------- ------------ HELPERS ------------------- -----------------------------

local Node = {}

function Node.CreateNode(): TNode
	return {}
end

function Node.CreateNodes(inputNames: { string }): TNodes
	local nodes: TNodes = {}
	for _, inputName in ipairs(inputNames) do
		nodes[inputName] = {}
	end
	return nodes
end

function Node.HasConnections(node: TNode?): boolean
	return node ~= nil and next(node) ~= nil
end

function Node.Connect(node: TNode, gate: TGate)
	node[gate] = true
end

function Node.Disconnect(node: TNode, gate: TGate)
	node[gate] = nil
end

function Node.Clear(node: TNode)
	table.clear(node)
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return Node
