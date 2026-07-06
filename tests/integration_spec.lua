---@diagnostic disable: undefined-global
---@module 'tests.integration_spec'
---@brief Integration tests for the full refactoring workflow
---@description
--- Tests core.refactor.rename_references end to end: given a rename/move that
--- already happened on disk, verifies references in other files and open
--- buffers get updated. Covers Lua, Python, and TypeScript/JavaScript, since
--- all three previously crashed or silently no-op'd (missing path-util
--- functions, a cache-dependent scanner that returned nothing on a project's
--- first scan, and a single global relative-import path that was only ever
--- correct for one specific referencing file).

local refactor = require("neotree-fs-refactor.core.refactor")

---@type Neotree.FSRefactor.Config
local test_config = {
  enabled = true,
  auto_save = false,
  notify_on_refactor = false,
  ignore_patterns = {},
  file_types = {
    lua = true,
    typescript = true,
    javascript = true,
    typescriptreact = true,
    javascriptreact = true,
    python = true,
  },
  max_file_size = 1024 * 1024,
  debounce_ms = 0,
}

-- A bare "/tmp/..." literal is ambiguous on native Windows Neovim (a leading
-- "/" resolves drive-relative to whatever drive is current, not to a real
-- /tmp), so resolve a real OS temp dir explicitly.
local test_dir = (vim.fn.has("win32") == 1 and vim.env.TEMP or "/tmp") .. "/test_neotree_fs_refactor_integration"

local function write(path, lines)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.fn.writefile(lines, path)
end

local function read(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  return ok and table.concat(lines, "\n") or nil
end

describe("integration: core.refactor.rename_references", function()
  local original_cwd

  before_each(function()
    original_cwd = vim.fn.getcwd()
    vim.fn.delete(test_dir, "rf")
    vim.fn.mkdir(test_dir, "p")
    -- The scanner searches vim.fn.getcwd(): scope it to the isolated fixture
    -- dir so it can't find (and rewrite!) unrelated matches in the repo
    -- itself, e.g. these very test files' own require()/import string literals.
    vim.fn.chdir(test_dir)
  end)

  after_each(function()
    vim.fn.chdir(original_cwd)
    vim.fn.delete(test_dir, "rf")
  end)

  it("updates require() references across a Lua directory rename", function()
    write(test_dir .. "/lua/testfs/rem/da.lua", { "return { greet = function() return 'hi' end }" })
    write(test_dir .. "/lua/testfs/init.lua", { 'local da = require("testfs.rem.da")', "return da" })
    write(test_dir .. "/lua/testfs/other.lua", { 'local da = require("testfs.rem.da")', "return da" })

    local old_dir = test_dir .. "/lua/testfs/rem"
    local new_dir = test_dir .. "/lua/testfs/remolus"
    vim.fn.rename(old_dir, new_dir)

    local ok = refactor.rename_references(old_dir, new_dir, test_config)
    assert.is_true(ok)

    assert.is_true(read(test_dir .. "/lua/testfs/init.lua"):find('require("testfs.remolus.da")', 1, true) ~= nil)
    assert.is_true(read(test_dir .. "/lua/testfs/other.lua"):find('require("testfs.remolus.da")', 1, true) ~= nil)
  end)

  it("updates require() references across a single Lua file rename", function()
    write(test_dir .. "/lua/testfs/rem/da.lua", { "return {}" })
    write(test_dir .. "/lua/testfs/init.lua", { 'local da = require("testfs.rem.da")', "return da" })

    local old_file = test_dir .. "/lua/testfs/rem/da.lua"
    local new_file = test_dir .. "/lua/testfs/rem/db.lua"
    vim.fn.rename(old_file, new_file)

    refactor.rename_references(old_file, new_file, test_config)

    assert.is_true(read(test_dir .. "/lua/testfs/init.lua"):find('require("testfs.rem.db")', 1, true) ~= nil)
  end)

  it("updates from/import module references across a Python rename", function()
    write(test_dir .. "/pkg/util/shared.py", { "def greet(): return 'hi'" })
    write(test_dir .. "/pkg/a.py", { "from pkg.util.shared import greet", "greet()" })

    local old_file = test_dir .. "/pkg/util/shared.py"
    local new_file = test_dir .. "/pkg/util/shared_utils.py"
    vim.fn.rename(old_file, new_file)

    refactor.rename_references(old_file, new_file, test_config)

    assert.is_true(read(test_dir .. "/pkg/a.py"):find("from pkg.util.shared_utils import greet", 1, true) ~= nil)
  end)

  it("computes the relative import specifier per referencing file, not globally", function()
    -- Regression test: TS/JS imports are relative to the importing file's own
    -- directory, so two files at different depths need different rewritten
    -- specifiers for the very same rename.
    write(test_dir .. "/src/util/shared.ts", { "export function greet() { return 'hi' }" })
    write(test_dir .. "/src/a.ts", { 'import { greet } from "./util/shared";' })
    write(test_dir .. "/src/nested/b.ts", { 'import { greet } from "../util/shared";' })

    local old_file = test_dir .. "/src/util/shared.ts"
    local new_file = test_dir .. "/src/util/shared_utils.ts"
    vim.fn.rename(old_file, new_file)

    refactor.rename_references(old_file, new_file, test_config)

    assert.is_true(read(test_dir .. "/src/a.ts"):find('from "./util/shared_utils"', 1, true) ~= nil)
    assert.is_true(read(test_dir .. "/src/nested/b.ts"):find('from "../util/shared_utils"', 1, true) ~= nil)
  end)

  it("does not touch a similarly-named but unrelated module", function()
    write(test_dir .. "/lua/testfs/rem/da.lua", { "return {}" })
    write(test_dir .. "/lua/testfs/other.lua", { 'local x = require("testfs.rem.da_other")' })

    local old_file = test_dir .. "/lua/testfs/rem/da.lua"
    local new_file = test_dir .. "/lua/testfs/rem/db.lua"
    vim.fn.rename(old_file, new_file)

    refactor.rename_references(old_file, new_file, test_config)

    assert.is_true(read(test_dir .. "/lua/testfs/other.lua"):find('require("testfs.rem.da_other")', 1, true) ~= nil)
  end)
end)
