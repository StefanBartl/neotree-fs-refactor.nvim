---@diagnostic disable: undefined-global
---@module 'tests.path_util_spec'
---@brief Test suite for path utility functions
---@description
--- Tests path normalization, module conversion, and path manipulation functions.

describe("path_util", function()
	local path_util = require("neotree-fs-refactor.utils.path")

	describe("normalize", function()
		it("should convert backslashes to forward slashes", function()
			assert.equals("path/to/file", path_util.normalize("path\\to\\file"))
		end)

		it("should remove duplicate slashes", function()
			assert.equals("path/to/file", path_util.normalize("path//to///file"))
		end)

		it("should remove trailing slash except for root", function()
			assert.equals("path/to/file", path_util.normalize("path/to/file/"))
			assert.equals("/", path_util.normalize("/"))
		end)

		it("should handle empty paths", function()
			assert.equals("", path_util.normalize(""))
            ---@diagnostic disable-next-line
			assert.equals("", path_util.normalize(nil))
		end)
	end)

	describe("file_to_module", function()
		it("should convert file path to module path", function()
			assert.equals("testfs.rem.da", path_util.file_to_module("lua/testfs/rem/da.lua"))
		end)

		it("should handle absolute paths with lua directory", function()
			assert.equals("testfs.core.utils", path_util.file_to_module("/home/user/project/lua/testfs/core/utils.lua"))
		end)

		it("should remove .lua extension", function()
			assert.equals("mymodule", path_util.file_to_module("lua/mymodule.lua"))
		end)

		it("should handle paths without lua directory", function()
			assert.equals("testfs.rem.da", path_util.file_to_module("testfs/rem/da.lua"))
		end)

		it("should return nil for invalid paths", function()
			---@diagnostic disable-next-line
			assert.is_nil(path_util.file_to_module(nil))
			assert.is_nil(path_util.file_to_module(""))
		end)

		it("should handle Windows-style paths", function()
			assert.equals("testfs.rem.da", path_util.file_to_module("C:\\Users\\user\\lua\\testfs\\rem\\da.lua"))
		end)
	end)

	describe("module_to_file", function()
		it("should convert module path to file path", function()
			local result = path_util.module_to_file("testfs.rem.da", "/project")
			assert.is_true(result:match("testfs/rem/da%.lua$") ~= nil)
		end)

		it("should handle base path with lua directory", function()
			local result = path_util.module_to_file("testfs.rem.da", "/project/lua")
			assert.is_true(result:match("testfs/rem/da%.lua$") ~= nil)
		end)

		it("should use cwd if no base path provided", function()
			local result = path_util.module_to_file("testfs.rem.da")
			assert.is_true(result:match("testfs/rem/da%.lua$") ~= nil)
		end)
	end)

	describe("join", function()
		it("should join multiple path components", function()
			assert.equals("path/to/file", path_util.join("path", "to", "file"))
		end)

		it("should handle mixed separators", function()
			assert.equals("path/to/file", path_util.join("path\\to", "file"))
		end)

		it("should normalize result", function()
			assert.equals("path/to/file", path_util.join("path//to", "/file"))
		end)
	end)

	describe("is_absolute", function()
		it("should detect Unix absolute paths", function()
			assert.is_true(path_util.is_absolute("/home/user/file"))
			assert.is_false(path_util.is_absolute("relative/path"))
		end)

		-- Note: Windows detection depends on platform
		it("should handle empty/nil paths", function()
			assert.is_false(path_util.is_absolute(""))
			---@diagnostic disable-next-line
			assert.is_false(path_util.is_absolute(nil))
		end)
	end)

	describe("relative", function()
		it("should return relative path when target is inside base", function()
			local result = path_util.relative("/home/user", "/home/user/project/file.lua")
			assert.equals("project/file.lua", result)
		end)

		it("should return full path when target is outside base", function()
			local result = path_util.relative("/home/user", "/other/path/file.lua")
			assert.equals("/other/path/file.lua", result)
		end)
	end)

	describe("is_inside", function()
		it("should detect when path is inside base", function()
			assert.is_true(path_util.is_inside("/home/user", "/home/user/project/file.lua"))
		end)

		it("should detect when path is outside base", function()
			assert.is_false(path_util.is_inside("/home/user", "/other/path/file.lua"))
		end)
	end)

	describe("parent", function()
		it("should return parent directory", function()
			assert.equals("/home/user", path_util.parent("/home/user/project"))
		end)

		it("should handle root directory", function()
			local result = path_util.parent("/")
			assert.equals("/", result)
		end)
	end)

	describe("filename", function()
		it("should extract filename from path", function()
			assert.equals("file.lua", path_util.filename("/home/user/project/file.lua"))
		end)

		it("should handle path with no directory", function()
			assert.equals("file.lua", path_util.filename("file.lua"))
		end)
	end)

	describe("equals", function()
		it("should compare normalized paths", function()
			assert.is_true(path_util.equals("path/to/file", "path//to/file"))
		end)

		it("should handle different paths", function()
			assert.is_false(path_util.equals("path/to/file1", "path/to/file2"))
		end)
	end)
end)
