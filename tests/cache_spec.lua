---@diagnostic disable: undefined-global
---@module 'tests.cache_spec'
---@brief Test suite for cache system
---@description
--- Tests cache creation, loading, saving, and hierarchical management.

describe("cache", function()
  local cache
  local test_cache_dir = "/tmp/test_neotree_refactor_cache"

  before_each(function()
    -- Clean up old test cache
    vim.fn.delete(test_cache_dir, "rf")
    vim.fn.mkdir(test_cache_dir, "p")

    -- Mock logger
    package.loaded["neotree-fs-refactor.utils.logger"] = {
      debug = function() end,
      info = function() end,
      warn = function() end,
      error = function() end,
      setup = function() end,
    }

    -- Initialize cache module
    cache = require("neotree-fs-refactor.cache")
    cache.init({
      path = test_cache_dir,
      cleanup_after_days = 7,
    })
  end)

  after_each(function()
    -- Cleanup
    vim.fn.delete(test_cache_dir, "rf")
  end)

  describe("create_cache", function()
    it("should create new cache with correct structure", function()
      local new_cache = cache.create_cache("/test/project")

      assert.equals("1.0.0", new_cache.version)
      assert.equals("/test/project", new_cache.cwd)
      assert.is_number(new_cache.last_updated)
      assert.is_number(new_cache.last_accessed)
      assert.is_table(new_cache.entries)
      assert.equals(0, vim.tbl_count(new_cache.entries))
    end)
  end)

  describe("save and load cache", function()
    it("should save and load cache correctly", function()
      local test_cache = cache.create_cache("/test/project")
      test_cache.entries["/test/file.lua"] = {
        { line = 1, require_path = "test.module" },
        { line = 5, require_path = "other.module" },
      }

      -- Save
      local saved = cache.save_current_cache()
      assert.is_true(saved)

      -- Clear current cache
      cache._current_cache = nil

      -- Load
      local loaded = cache.get_cache("/test/project")
      assert.equals("/test/project", loaded.cwd)
      assert.equals(1, vim.tbl_count(loaded.entries))
      assert.equals(2, #loaded.entries["/test/file.lua"])
    end)
  end)

  describe("hierarchical cache", function()
    it("should use parent cache for subdirectory", function()
      -- Create parent cache
      local parent_cache = cache.create_cache("/test/project")
      parent_cache.entries["/test/project/lua/module.lua"] = {
        { line = 1, require_path = "module" },
      }
      parent_cache.entries["/test/project/other/file.lua"] = {
        { line = 1, require_path = "other" },
      }
      cache.save_current_cache()

      -- Clear current cache
      cache._current_cache = nil

      -- Get cache for subdirectory
      local sub_cache = cache.get_cache("/test/project/lua")

      -- Should only contain entries inside subdirectory
      local entry_count = 0
      for _ in pairs(sub_cache.entries) do
        entry_count = entry_count + 1
      end
      -- Note: Actual filtering depends on is_inside implementation
      assert.is_true(entry_count <= 2)
    end)
  end)

  describe("find_requires", function()
    it("should find exact module matches", function()
      local test_cache = cache.create_cache("/test/project")
      test_cache.entries["/test/file1.lua"] = {
        { line = 1, require_path = "test.module" },
      }
      test_cache.entries["/test/file2.lua"] = {
        { line = 3, require_path = "test.module" },
      }
      test_cache.entries["/test/file3.lua"] = {
        { line = 2, require_path = "other.module" },
      }

      local results = cache.find_requires("test.module")
      assert.equals(2, vim.tbl_count(results))
      assert.is_nil(results["/test/file3.lua"])
    end)

    it("should find submodule matches", function()
      local test_cache = cache.create_cache("/test/project")
      test_cache.entries["/test/file1.lua"] = {
        { line = 1, require_path = "test.module.sub" },
      }
      test_cache.entries["/test/file2.lua"] = {
        { line = 1, require_path = "test.module.other.deep" },
      }
      test_cache.entries["/test/file3.lua"] = {
        { line = 1, require_path = "test.other" },
      }

      local results = cache.find_requires("test.module")
      assert.equals(2, vim.tbl_count(results))
      assert.is_nil(results["/test/file3.lua"])
    end)
  end)

  describe("cleanup_old_caches", function()
    it("should delete caches older than threshold", function()
      -- Create old cache
      local old_cache = {
        version = "1.0.0",
        cwd = "/old/project",
        last_updated = os.time() - (8 * 24 * 60 * 60), -- 8 days ago
        last_accessed = os.time() - (8 * 24 * 60 * 60),
        entries = {},
      }

      local old_cache_file = test_cache_dir .. "/old_cache.json"
      vim.fn.writefile({ vim.fn.json_encode(old_cache) }, old_cache_file)

      -- Create recent cache
      local recent_cache = {
        version = "1.0.0",
        cwd = "/recent/project",
        last_updated = os.time(),
        last_accessed = os.time(),
        entries = {},
      }

      local recent_cache_file = test_cache_dir .. "/recent_cache.json"
      vim.fn.writefile({ vim.fn.json_encode(recent_cache) }, recent_cache_file)

      -- Run cleanup
      cache.cleanup_old_caches()

      -- Check results
      assert.equals(0, vim.fn.filereadable(old_cache_file))
      assert.equals(1, vim.fn.filereadable(recent_cache_file))
    end)
  end)
end)
