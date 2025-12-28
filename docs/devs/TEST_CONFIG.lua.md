-- Test configuration for debugging neotree-fs-refactor
-- Load this in your Neovim config to enable verbose logging

require("neotree-fs-refactor").setup({
  enabled = true,
  auto_save = true, -- Enable auto-save for testing
  notify_on_refactor = true,

  -- Use minimal ignore patterns for testing
  ignore_patterns = {
    ".git/**",
  },

  -- Enable all file types
  file_types = {
    lua = true,
    typescript = true,
    javascript = true,
    typescriptreact = true,
    javascriptreact = true,
    python = true,
  },

  max_file_size = 10 * 1024 * 1024, -- 10MB for testing
  debounce_ms = 10, -- Shorter debounce for faster testing
})

-- Enable debug logging
vim.lsp.set_log_level("debug")

-- Helper function to test the plugin
local function test_refactor()
  local path_utils = require("neotree-fs-refactor.utils.path")
  local scanner = require("neotree-fs-refactor.utils.scanner")

  print("\n=== Testing Path Utils ===")

  local test_paths = {
    "lua/testfs/eins.lua",
    "lua/testfs/hehe/dada/init.lua",
    "lua/testfs/util/init.lua",
  }

  for _, path in ipairs(test_paths) do
    local full_path = vim.fn.getcwd() .. "/" .. path
    local module = path_utils.file_to_module(full_path)
    print(string.format("  %s -> %s", path, module))
  end

  print("\n=== Testing Scanner ===")

  -- Test finding references to eins.lua
  local test_file = vim.fn.getcwd() .. "/lua/testfs/eins.lua"
  local config = require("neotree-fs-refactor").config
  local files = scanner.find_files_with_references(vim.fn.getcwd(), test_file, config)

  print(string.format("  Found %d files referencing eins.lua:", #files))
  for _, file in ipairs(files) do
    print(string.format("    - %s", vim.fn.fnamemodify(file, ":~:.")))
  end
end

-- Create test command
vim.api.nvim_create_user_command("TestRefactor", test_refactor, {
  desc = "Test neotree-fs-refactor plugin"
})

print([[
=== neotree-fs-refactor Test Config Loaded ===
Commands available:
  :TestRefactor         - Run diagnostic tests
  :NeotreeRefactorStatus - Show plugin status

To test:
1. Open neo-tree (:Neotree)
2. Navigate to lua/testfs/eins.lua
3. Press 'r' to rename to eins_new.lua
4. Check if lua/testfs/init.lua was updated

Debug tips:
- Check :messages for debug output
- Enable verbose: :set verbose=9
- Check logs: :edit ~/.local/state/nvim/lsp.log
]])
