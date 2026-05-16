local TestService = {}

local OK = function(name) return "Test " .. name .. ": Passed" end
local WRONG = function(name, output, expected) return "Test " .. name .. ": Failed.\n\tWrong output: \"" .. (output or "nil") .. "\"\n\tExpected: \"" .. expected end 
local ERROR = function(name, output, expected) return "Test " .. name .. ": Failed.\n\tThrew error: \"" .. (output or "nil") .. "\"\n\tExpected:    \"" .. expected end

local function assert_equals(test, value)
  local success, result = pcall(test.Func, table.unpack(test.Args, 1, test.Args.n))
  if success then
    print(if result == value then OK(test.Name) else WRONG(test.Name, result, value))
  else print(ERROR(test.Name, result, value)) end
end

local function assert_notequals(test, value)
  local success, result = pcall(test.Func, table.unpack(test.Args, 1, test.Args.n))
  if success then
    print(if result ~= value then OK(test.Name) else WRONG(test.Name, result, value))
  else print(ERROR(test.Name, result, value)) end
end

local function assert_success(test)
  local success, result = pcall(test.Func, table.unpack(test.Args, 1, test.Args.n))
  if success then
    print(OK(test.Name))
  else print(ERROR(test.Name, result, "None")) end
end

local function assert_error(test, output: string)
  local success, result = pcall(test.Func, table.unpack(test.Args, 1, test.Args.n))
  if success then
    print(WRONG(test.Name, result, output))
  else print(if result:match("^.-:%d+: (.*)$") == output then OK(test.Name) else ERROR(test.Name, result:match("^.-:%d+: (.*)$"), output)) end
end

local function assert_effect(test, effect)
  local success, result = pcall(test.Func, table.unpack(test.Args, 1, test.Args.n))
  if success then
    local e_success, e_result = pcall(effect)
    if e_success then
      print(if e_result then OK(test.Name) else WRONG(test.Name, e_result, "Other effect"))
    else print(ERROR(test.Name, e_result), "Other effect") end
  else print(ERROR(test.Name, result, "Other effect")) end
end

function TestService.Test(name, func, ...)
  local test = { Name = name, Func = func, Args = table.pack(...) }
  test.AssertEquals = function(value) return assert_equals(test, value) end
  test.AssertNotEquals = function(value) return assert_notequals(test, value) end
  test.AssertSuccess = function() return assert_success(test) end
  test.AssertError  = function(output) return assert_error(test, output)  end
  test.AssertEffect = function(effect) return assert_effect(test, effect) end
  return test
end

return TestService
