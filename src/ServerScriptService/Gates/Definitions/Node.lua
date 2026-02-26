--!strict
--[[ NODE
    This module just has some useful functionality for a Gate's nodes.

    Node is a simple number array, that stores the IDs of the gates connected to it.
    NodeInformation stores information about a general Gate's nodes
      - Amount of Input nodes.
      - If it has an output node.
      - All the gate's input nodes by name.
    
]]

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- -----------------------------

export type TNode =  { [number]: true }
export type TNodes = { [string]: TNode }

export type TNodeInformation = {
  HasOutput: boolean,
  InputCount: number,
  Inputs: { string }
}

-- ----------------------------- ------------- END OF MODULE ------------- ---------------------------

return true
