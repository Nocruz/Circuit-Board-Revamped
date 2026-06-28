return {
  Nodes = { Outputs = { "Output" }, Inputs = { "Input", "Phrase", "Index" } },
  DefaultVisuals = {
    MainMaterial = Enum.Material.Marble,
    MainColor = Color3.fromRGB(13, 22, 122),
    InputOffsets = { Vector2.new(0.00, 0.50), Vector2.new(0.50, 0.25), Vector2.new(0.50, -0.15) }
  },
  AttributeData = {
    ["Phrase"] = { Default = "", Predicates = { } },
    ["Index"] = { Default = 0, Predicates = { function(value) return value >= 0 end } },
  },

  Process = function(self)
    local input = self:ReadInput("Input")
    input = if input.AsBoolean() then input.AsString() else ""

    local hasPhraseConnection, phrase = self:ReadAttributeFromNode("Phrase", "Phrase")
    phrase = if hasPhraseConnection then phrase.AsString() else phrase
    local hasIndexConnection, index = self:ReadAttributeFromNode("Index", "Index")
    index = math.floor(if hasIndexConnection then index.AsNumber() else index)

    -- Negative index -> not found
    if index < 0 then
      self.Nodes.Signals["Output"] = -1
      return
    end

    -- Empty phrase: define behavior as only index 0 valid at position 0
    if phrase == "" then
      self.Nodes.Signals["Output"] = if index == 0 and #input > 0 then 1 else -1
      return
    end

    -- Fast path: look for the first occurrence if index == 0
    if index == 0 then
      local s = string.find(input, phrase, 1, true)
      self.Nodes.Signals["Output"] = if s then s else -1
      return
    end

    -- Find the start position for the requested index lazily:
    -- Lazy search: advance through occurrences until we reach the requested one
    local startPos = 1
    local found = false
    for i = 1, index do
      local s, e = string.find(input, phrase, startPos, true)
      if not s then
        -- Fewer occurrences than requested -> not found
        self.Nodes.Signals["Output"] = -1
        return
      end
      startPos = e + 1
      found = true
    end

    if not found then
      self.Nodes.Signals["Output"] = -1
      return
    end

    -- Simpler and robust: find the index-th occurrence by searching from 1 and counting
    local count = 0
    local pos = 1
    while true do
      local s, e = string.find(input, phrase, pos, true)
      if not s then
        self.Nodes.Signals["Output"] = -1
        return
      end
      if count == index then
        self.Nodes.Signals["Output"] = s
        return
      end
      count = count + 1
      pos = e + 1
    end
  end
}
