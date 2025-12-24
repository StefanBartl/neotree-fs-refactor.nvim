---@module 'neotree_fs_refactor'
---@brief Main entry point for neotree-fs-refactor plugin
---@description
--- Provides setup function and public API for the plugin.
--- Coordinates configuration, Neo-tree integration, and user commands.

local config = require("neotree_fs_refactor.config")
local neotree = require("neotree_fs_refactor.neotree")
local orchestrator = require("neotree_fs_refactor.orchestrator")
local preview = require("neotree_fs_refactor.ui.preview")
local notify = require("neotree_fs_refactor.utils.notify")

local M = {}

local api = vim.api

---Plugin version
M.version = "0.1.0"

---Whether plugin is initialized
local initialized = false

---Setup plugin with user configuration
---@param opts Neotree.FSRefactor.Config|nil User configuration
---@return nil
function M.setup(opts)
	if initialized then
		notify.warn("neotree-fs-refactor already initialized")
		return
	end

	-- Initialize configuration
	config.setup(opts or {})

	-- Validate configuration
	local valid, err = config.validate()
	if not valid then
		notify.error("Invalid configuration: " .. (err or "unknown error"))
		return
	end

	-- Register Neo-tree hooks
	local hooks_ok, hooks_err = neotree.register_hooks()
	if not hooks_ok then
		notify.error("Failed to register Neo-tree hooks: " .. (hooks_err or "unknown error"))
		return
	end

	-- Create user commands
	M.create_commands()

	initialized = true

	local level = config.get_notify_level()
	if level <= vim.log.levels.INFO then
		notify.info("v" .. M.version .. " initialized")
	end
end

---Create user commands
---@return nil
function M.create_commands()
	-- Command to manually trigger refactoring
	api.nvim_create_user_command("NeotreeRefactor", function(cmd_opts)
		local args = cmd_opts.fargs

		if #args < 2 then
			notify.error("Usage: :NeotreeRefactor <old_path> <new_path>")
			return
		end

		local old_path = args[1]
		local new_path = args[2]

		M.refactor_path(old_path, new_path)
	end, {
		nargs = "+",
		desc = "Manually trigger refactoring for path change",
	})

	-- Command to show plugin info
	api.nvim_create_user_command("NeotreeRefactorInfo", function()
		M.show_info()
	end, {
		desc = "Show neotree-fs-refactor plugin information",
	})

	-- Command to reload configuration
	api.nvim_create_user_command("NeotreeRefactorReload", function()
		M.reload()
	end, {
		desc = "Reload neotree-fs-refactor configuration",
	})
end

---Manually trigger refactoring for a path change
---@param old_path string Original path
---@param new_path string New path
---@return nil
function M.refactor_path(old_path, new_path)
	if not initialized then
		notify.error("Plugin not initialized. Call setup() first.")
		return
	end

	-- Create operation
	local operation = {
		type = "rename",
		old_path = old_path,
		new_path = new_path,
		is_directory = vim.fn.isdirectory(old_path) == 1,
		timestamp = os.time(),
	}

	-- Create plan
	local plan, err = orchestrator.create_plan(operation)
	if not plan then
		notify.error("Failed to create plan: " .. (err or "unknown error"))
		return
	end

	-- Show preview or execute
	if config.should_show_preview() then
		preview.show_preview(plan, function(confirmed)
			if confirmed then
				plan.reviewed = true
				orchestrator.execute_plan(plan, false)
			else
				notify.info("Refactoring cancelled")
			end
		end)
	else
		plan.reviewed = true
		orchestrator.execute_plan(plan, true)
	end
end

---Show plugin information
---@return nil
function M.show_info()
	local lines = {
		"neotree-fs-refactor v" .. M.version,
		"",
		"Configuration:",
		"  LSP enabled: " .. tostring(config.is_lsp_enabled()),
		"  Fallback enabled: " .. tostring(config.is_fallback_enabled()),
		"  Auto-apply: " .. tostring(config.should_auto_apply()),
		"  Preview: " .. tostring(config.should_show_preview()),
		"",
		"Active LSP servers:",
	}

	local clients = vim.lsp.get_clients()
	if #clients == 0 then
		lines[#lines + 1] = "  (none)"
	else
		for i = 1, #clients do
			lines[#lines + 1] = "  - " .. clients[i].name
		end
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = "Fallback tool: " .. config.get("fallback").tool

	-- Show in floating window
	local buf = api.nvim_create_buf(false, true)
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	api.nvim_set_option_value("modifiable", false, { buf = buf })

	api.nvim_set_option_value("filetype", "markdown", { buf = buf })

	local ui = api.nvim_list_uis()[1]
	local width = 60
	local height = #lines + 2
	local row = math.floor((ui.height - height) / 2)
	local col = math.floor((ui.width - width) / 2)

	local win = api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Plugin Info ",
		title_pos = "center",
	})

	vim.keymap.set("n", "q", function()
		api.nvim_win_close(win, true)
	end, { buffer = buf })

	vim.keymap.set("n", "<Esc>", function()
		api.nvim_win_close(win, true)
	end, { buffer = buf })
end

---Reload plugin configuration
---@return nil
function M.reload()
	if not initialized then
		notify.warn("Plugin not initialized")
		return
	end

	-- Reset config
	config.reset()

	-- Reinitialize
	initialized = false
	M.setup({})

	notify.info("Configuration reloaded")
end

---Get current configuration (for debugging)
---@return Neotree.FSRefactor.Config|nil
function M.get_config()
	local cfg = config.get_all()

	if not cfg then
		notify.error("cfg is nil")
		return nil
	end

	return cfg
end

---Check if plugin is initialized
---@return boolean
function M.is_initialized()
	return initialized
end

return M
