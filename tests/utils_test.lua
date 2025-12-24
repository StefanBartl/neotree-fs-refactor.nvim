---@module 'tests.utils_test'

local test_utils = require("tests.test_utils")
local utils = require("neotree_fs_refactor.utils")

local tests = {}

function tests.test_normalize_path()
	local path1 = utils.normalize_path("C:\\Users\\test\\file.lua")
	test_utils.assert_equal(path1, "C:/Users/test/file.lua", "Should normalize backslashes")

	local path2 = utils.normalize_path("/home/user/file.lua")
	test_utils.assert_equal(path2, "/home/user/file.lua", "Should keep forward slashes")
end

function tests.test_basename()
	local name1 = utils.basename("/home/user/project/file.lua")
	test_utils.assert_equal(name1, "file.lua", "Should extract filename")

	local name2 = utils.basename("file.lua")
	test_utils.assert_equal(name2, "file.lua", "Should handle filename without path")
end

function tests.test_dirname()
	local dir1 = utils.dirname("/home/user/project/file.lua")
	test_utils.assert_equal(dir1, "/home/user/project", "Should extract directory")

	local dir2 = utils.dirname("file.lua")
	test_utils.assert_equal(dir2, ".", "Should return . for bare filename")
end

function tests.test_escape_pattern()
	local escaped = utils.escape_pattern("test.file.lua")
	test_utils.assert_true(escaped:find("%.") ~= nil, "Should escape dots")

	local result = ("test.file.lua"):find(escaped, 1, true)
	test_utils.assert_not_nil(result, "Escaped pattern should match original")
end

-- Run tests
test_utils.run_suite("Utils Tests", tests)
