---@module 'neotree-fs-refactor.core.event_handlers'
---@brief Handles neo-tree file operation events
---@description
--- This module registers event handlers for neo-tree file operations:
--- - file_renamed: When a file/folder is renamed
--- - file_moved: When a file/folder is moved
--- - file_deleted: When a file/folder is deleted
---
--- Events are debounced to avoid excessive operations.

local refactor = require("neotree-fs-refactor.core.refactor")
local utils = require("neotree-fs-refactor.utils.helpers")
local notify = require("neotree-fs-refactor.utils.notify")

local M = {}

---@type Neotree.FSRefactor.Config|nil
local config = nil

---@type table<string, uv.uv_timer_t>
local debounce_timers = {}

---Debounced execution of refactor operations
---@param key string Unique key for the operation
---@param callback function Function to execute
---@param delay number Delay in milliseconds
---@return nil
local function debounce(key, callback, delay)
	-- Cancel existing timer
	if debounce_timers[key] then
		debounce_timers[key]:stop()
		debounce_timers[key]:close()
	end

	-- Create new timer
	local timer = vim.loop.new_timer()

	if not timer then
		notify.warn("timer is nil")
		return nil
	end

	---@cast timer uv.uv_timer_t

	debounce_timers[key] = timer

	timer:start(
		delay,
		0,
		vim.schedule_wrap(function()
			callback()
			timer:stop()
			timer:close()
			debounce_timers[key] = nil
		end)
	)
end

---Handle file rename events
---@param args table Event arguments from neo-tree
---@return nil
local function on_file_renamed(args)
	if not args or not args.source or not args.destination then
		return nil
	end

	if not config then
		notify.warn("config is nil")
		return nil
	end

	local old_path = args.source
	local new_path = args.destination

	debounce("rename_" .. old_path, function()
		local success, changes = refactor.rename_references(old_path, new_path, config)

		if success and changes and config.notify_on_refactor then
			utils.notify_refactor_result("rename", old_path, new_path, changes)
		end
	end, config.debounce_ms)
end

---Handle file move events
---@param args table Event arguments from neo-tree
---@return nil
local function on_file_moved(args)
	if not args or not args.source or not args.destination then
		return
	end

	if not config then
		notify.warn("config is nil")
		return nil
	end

	local old_path = args.source
	local new_path = args.destination

	debounce("move_" .. old_path, function()
		local success, changes = refactor.move_references(old_path, new_path, config)

		if success and changes and config.notify_on_refactor then
			utils.notify_refactor_result("move", old_path, new_path, changes)
		end
	end, config.debounce_ms)
end

---Handle file delete events
---@param args string|table Full path to deleted file or event args
---@return nil
local function on_file_deleted(args)
    if not config then
        notify.warn("config is nil")
        return nil
    end

    local deleted_path

	if type(args) == "string" then
		deleted_path = args
	elseif type(args) == "table" and args.path then
		deleted_path = args.path
	else
		return
	end

	debounce("delete_" .. deleted_path, function()
		local success, changes = refactor.delete_references(deleted_path, config)

		if success and changes and config.notify_on_refactor then
			utils.notify_refactor_result("delete", deleted_path, nil, changes)
		end
	end, config.debounce_ms)
end

---Register neo-tree event handlers
---@param user_config Neotree.FSRefactor.Config Plugin configuration
---@return nil
function M.setup(user_config)
	config = user_config

	-- Try to get neo-tree events module
	local events_ok, events = pcall(require, "neo-tree.events")
	if not events_ok then
		notify.error("Could not load neo-tree.events")
		return
	end

	-- Get neo-tree manager
	local manager_ok, _ = pcall(require, "neo-tree.sources.manager")
	if not manager_ok then
		notify.warn("Could not load neo-tree.sources.manager")
	end

	-- Subscribe to neo-tree filesystem events
	local event_handlers = {
		{
			event = events.FILE_RENAMED,
			handler = on_file_renamed,
		},
		{
			event = events.FILE_MOVED,
			handler = on_file_moved,
		},
		{
			event = events.FILE_DELETED,
			handler = on_file_deleted,
		},
	}

	-- Register handlers with neo-tree
	for _, handler_config in ipairs(event_handlers) do
		events.subscribe(handler_config)
	end

	notify.debug("Event handlers registered")
end

---Cleanup function to stop all timers
---@return nil
function M.cleanup()
	for _, timer in pairs(debounce_timers) do
		if timer and not timer:is_closing() then
			timer:stop()
			timer:close()
		end
	end
	debounce_timers = {}
end

return M
