---@module 'tests.test_utils'
---@brief Testing utilities and framework
---@description
--- Simple testing framework for plugin validation.
--- Provides assertion helpers and test runners.

local M = {}

local str_format = string.format

---Test results tracking
---@class TestResults
---@field passed integer Number of passed tests
---@field failed integer Number of failed tests
---@field errors string[] Error messages

---@type TestResults
local results = {
  passed = 0,
  failed = 0,
  errors = {},
}

---Reset test results
local function reset_results()
  results.passed = 0
  results.failed = 0
  results.errors = {}
end

---Assert that condition is true
---@param condition boolean Condition to check
---@param message string Error message if false
---@return boolean success
function M.assert_true(condition, message)
  if condition then
    results.passed = results.passed + 1
    return true
  else
    results.failed = results.failed + 1
    results.errors[#results.errors + 1] = message or "Assertion failed"
    return false
  end
end

---Assert that condition is false
---@param condition boolean Condition to check
---@param message string Error message if true
---@return boolean success
function M.assert_false(condition, message)
  return M.assert_true(not condition, message or "Expected false, got true")
end

---Assert that values are equal
---@param actual any Actual value
---@param expected any Expected value
---@param message string|nil Custom error message
---@return boolean success
function M.assert_equal(actual, expected, message)
  if actual == expected then
    results.passed = results.passed + 1
    return true
  else
    results.failed = results.failed + 1
    local err = message or str_format("Expected %s, got %s", tostring(expected), tostring(actual))
    results.errors[#results.errors + 1] = err
    return false
  end
end

---Assert that value is not nil
---@param value any Value to check
---@param message string|nil Custom error message
---@return boolean success
function M.assert_not_nil(value, message)
  return M.assert_true(value ~= nil, message or "Value is nil")
end

---Assert that value is nil
---@param value any Value to check
---@param message string|nil Custom error message
---@return boolean success
function M.assert_nil(value, message)
  return M.assert_true(value == nil, message or "Value is not nil")
end

---Run a test function safely
---@param name string Test name
---@param test_fn function Test function
local function run_test(name, test_fn)
  print(str_format("Running: %s", name))

  local ok, err = pcall(test_fn)

  if not ok then
    results.failed = results.failed + 1
    results.errors[#results.errors + 1] = str_format("[%s] %s", name, tostring(err))
    print(str_format("  ❌ FAILED: %s", tostring(err)))
  else
    print(str_format("  ✓ PASSED"))
  end
end

---Test suite runner
---@param suite_name string Suite name
---@param tests table<string, function> Map of test name to test function
function M.run_suite(suite_name, tests)
  print(string.rep("=", 60))
  print(str_format("Test Suite: %s", suite_name))
  print(string.rep("=", 60))

  reset_results()

  for name, test_fn in pairs(tests) do
    run_test(name, test_fn)
  end

  print(string.rep("=", 60))
  print(str_format("Results: %d passed, %d failed", results.passed, results.failed))

  if #results.errors > 0 then
    print("\nErrors:")
    for i = 1, #results.errors do
      print(str_format("  %d. %s", i, results.errors[i]))
    end
  end

  print(string.rep("=", 60))

  return results.failed == 0
end

return M
