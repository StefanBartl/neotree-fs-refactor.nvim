---@module 'tests.integration_test'

local test_utils = require("tests.test_utils")

local tests = {}

function tests.test_plugin_load()
  local ok, plugin = pcall(require, "neotree_fs_refactor")
  test_utils.assert_true(ok, "Plugin should load without errors")
  test_utils.assert_not_nil(plugin.setup, "Plugin should have setup function")
end

function tests.test_all_modules_load()
  local modules = {
    "neotree_fs_refactor.config",
    "neotree_fs_refactor.utils",
    "neotree_fs_refactor.lsp",
    "neotree_fs_refactor.fallback",
    "neotree_fs_refactor.orchestrator",
    "neotree_fs_refactor.ui.preview",
    "neotree_fs_refactor.neotree",
    "neotree_fs_refactor.health",
  }

  for i = 1, #modules do
    local ok, _ = pcall(require, modules[i])
    test_utils.assert_true(ok, string.format("Module %s should load", modules[i]))
  end
end

function tests.test_health_check()
  local ok, health = pcall(require, "neotree_fs_refactor.health")
  test_utils.assert_true(ok, "Health module should load")
  test_utils.assert_not_nil(health.check, "Health should have check function")
end

-- Run tests
test_utils.run_suite("Integration Tests", tests)

