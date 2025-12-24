---@module 'tests.config_test'

local test_utils = require("tests.test_utils")
local config = require("neotree_fs_refactor.config")

local tests = {}

function tests.test_default_config()
  config.reset()
  config.setup()

  test_utils.assert_true(config.is_lsp_enabled(), "LSP should be enabled by default")
  test_utils.assert_true(config.is_fallback_enabled(), "Fallback should be enabled by default")
  test_utils.assert_false(config.should_auto_apply(), "Auto-apply should be disabled by default")
  test_utils.assert_true(config.should_show_preview(), "Preview should be enabled by default")
end

function tests.test_custom_config()
  config.reset()
  config.setup({
    enable_lsp = false,
    auto_apply = true,
    timeout_ms = 10000,
  })

  test_utils.assert_false(config.is_lsp_enabled(), "LSP should be disabled")
  test_utils.assert_true(config.should_auto_apply(), "Auto-apply should be enabled")
  test_utils.assert_equal(config.get("timeout_ms"), 10000, "Timeout should be 10000")
end

function tests.test_validation()
  config.reset()
  config.setup({ timeout_ms = 100000 })

  local valid, err = config.validate()
  test_utils.assert_false(valid, "Should reject invalid timeout")
  test_utils.assert_not_nil(err, "Should return error message")
end

-- Run tests
test_utils.run_suite("Configuration Tests", tests)


