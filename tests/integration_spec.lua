---@diagnostic disable: undefined-global
---@module 'tests.integration_spec'
---@brief Integration tests for full refactoring workflow
---@description
--- Tests the complete flow from file rename to require updates.

describe("integration tests", function()
	local test_project_dir = "/tmp/test_refactor_project"
	local refactor

	before_each(function()
		-- Clean up
		vim.fn.delete(test_project_dir, "rf")
		vim.fn.mkdir(test_project_dir .. "/lua/testfs/rem", "p")

		-- Create test project structure
		-- testfs/rem/da.lua
		vim.fn.writefile({
			"local M = {}",
			"function M.test() return 'original' end",
			"return M",
		}, test_project_dir .. "/lua/testfs/rem/da.lua")

		-- testfs/init.lua (uses rem.da)
		vim.fn.writefile({
			'local remda = require("testfs.rem.da")',
			"",
			"local function main()",
			"  print(remda.test())",
			"end",
			"",
			"return { main = main }",
		}, test_project_dir .. "/lua/testfs/init.lua")

		-- Initialize plugin
		---@diagnostic disable-next-line
		require("neotree-fs-refactor").setup({
			cache = {
				enabled = true,
				method = "async_lua",
				path = "/tmp/test_integration_cache",
			},
			refactor = {
				show_picker = false,
				dry_run = false,
			},
			ui = {
				log_level = "error",
			},
		})

		refactor = require("neotree-fs-refactor.refactor")
	end)

	after_each(function()
		vim.fn.delete(test_project_dir, "rf")
		vim.fn.delete("/tmp/test_integration_cache", "rf")
	end)

	it("should update requires when directory is renamed", function()
		-- Build cache
		local cache = require("neotree-fs-refactor.cache")
		local test_cache = cache.create_cache(test_project_dir)

		-- Manually populate cache (simulating scan)
		test_cache.entries[test_project_dir .. "/lua/testfs/init.lua"] = {
			{ line = 1, require_path = "testfs.rem.da" },
		}
		cache._current_cache = test_cache
		cache.save_current_cache()

		-- Simulate rename: rem → remolus
		local old_dir = test_project_dir .. "/lua/testfs/rem"
		local new_dir = test_project_dir .. "/lua/testfs/remolus"

		-- Actually rename the directory
		vim.fn.rename(old_dir, new_dir)

		-- Trigger refactor
		refactor.handle_rename(old_dir, new_dir)

		-- Give it time to complete (async operations)
		vim.wait(2000, function()
			return false
		end)

		-- Verify the require was updated
		local updated_content = vim.fn.readfile(test_project_dir .. "/lua/testfs/init.lua")
		local found_updated = false

		for _, line in ipairs(updated_content) do
			if line:match('require%("testfs%.remolus%.da"%)') then
				found_updated = true
				break
			end
		end

		assert.is_true(found_updated, "Require statement should be updated to testfs.remolus.da")
	end)

	it("should handle file rename", function()
		-- Build cache
		local cache = require("neotree-fs-refactor.cache")
		local test_cache = cache.create_cache(test_project_dir)

		test_cache.entries[test_project_dir .. "/lua/testfs/init.lua"] = {
			{ line = 1, require_path = "testfs.rem.da" },
		}
		cache._current_cache = test_cache
		cache.save_current_cache()

		-- Simulate rename: da.lua → db.lua
		local old_file = test_project_dir .. "/lua/testfs/rem/da.lua"
		local new_file = test_project_dir .. "/lua/testfs/rem/db.lua"

		vim.fn.rename(old_file, new_file)

		-- Trigger refactor
		refactor.handle_rename(old_file, new_file)

		vim.wait(2000, function()
			return false
		end)

		-- Verify
		local updated_content = vim.fn.readfile(test_project_dir .. "/lua/testfs/init.lua")
		local found_updated = false

		for _, line in ipairs(updated_content) do
			if line:match('require%("testfs%.rem%.db"%)') then
				found_updated = true
				break
			end
		end

		assert.is_true(found_updated, "Require should be updated to testfs.rem.db")
	end)

	it("should update multiple files with same require", function()
		-- Create second file using rem.da
		vim.fn.writefile({
			'local shared = require("testfs.rem.da")',
			"return shared",
		}, test_project_dir .. "/lua/testfs/other.lua")

		-- Build cache
		local cache = require("neotree-fs-refactor.cache")
		local test_cache = cache.create_cache(test_project_dir)

		test_cache.entries[test_project_dir .. "/lua/testfs/init.lua"] = {
			{ line = 1, require_path = "testfs.rem.da" },
		}
		test_cache.entries[test_project_dir .. "/lua/testfs/other.lua"] = {
			{ line = 1, require_path = "testfs.rem.da" },
		}
		cache._current_cache = test_cache
		cache.save_current_cache()

		-- Rename directory
		local old_dir = test_project_dir .. "/lua/testfs/rem"
		local new_dir = test_project_dir .. "/lua/testfs/remolus"
		vim.fn.rename(old_dir, new_dir)

		refactor.handle_rename(old_dir, new_dir)
		vim.wait(2000, function()
			return false
		end)

		-- Verify both files were updated
		local init_updated = false
		local other_updated = false

		local init_content = vim.fn.readfile(test_project_dir .. "/lua/testfs/init.lua")
		for _, line in ipairs(init_content) do
			if line:match("testfs%.remolus%.da") then
				init_updated = true
				break
			end
		end

		local other_content = vim.fn.readfile(test_project_dir .. "/lua/testfs/other.lua")
		for _, line in ipairs(other_content) do
			if line:match("testfs%.remolus%.da") then
				other_updated = true
				break
			end
		end

		assert.is_true(init_updated, "init.lua should be updated")
		assert.is_true(other_updated, "other.lua should be updated")
	end)
end)
