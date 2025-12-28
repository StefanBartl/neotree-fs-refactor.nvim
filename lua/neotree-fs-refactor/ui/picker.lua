---@module 'neotree-fs-refactor.ui.picker'
---@brief Interactive picker for require changes
---@description
--- Provides a Telescope/FZF-Lua picker to review and select which
--- require statements should be updated.

local M = {}

local logger = require("neotree-fs-refactor.utils.logger")

---@type table<RequireChange, boolean>
local selected_items = {}

--- Show picker with changes
---@param changes RequireChange[] List of changes
---@param on_confirm fun(selected: RequireChange[]) Callback with selected changes
---@return nil
function M.show(changes, on_confirm)
    ---@diagnostic disable-next-line
	local main = require("neotree-fs-refactor")
	local config = main.get_config()

	if not config then
		logger.error("Plugin not initialized")
		return
	end

	-- Initialize selection state
	selected_items = {}
	for _, change in ipairs(changes) do
		selected_items[change] = false
	end

	-- Try Telescope first
	if config.ui.picker == "telescope" then
		local ok = pcall(M.show_telescope, changes, on_confirm)
		if ok then
			return
		end
		logger.warn("Telescope not available, falling back to FZF-Lua")
	end

	-- Fallback to FZF-Lua
	local ok = pcall(M.show_fzf, changes, on_confirm)
	if ok then
		return
	end

	-- No picker available, just apply all
	logger.warn("No picker available, applying all changes")
	on_confirm(changes)
end

--- Show Telescope picker
---@param changes RequireChange[] List of changes
---@param on_confirm fun(selected: RequireChange[]) Callback
---@return nil
function M.show_telescope(changes, on_confirm)
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local previewers = require("telescope.previewers")

	-- Create custom entry maker
	local function entry_maker(change)
		local display_text = string.format(
			"%s:%d | %s → %s",
			vim.fn.fnamemodify(change.file, ":~:."),
			change.line,
			change.old_require,
			change.new_require
		)

		return {
			value = change,
			display = display_text,
			ordinal = change.file .. ":" .. change.line,
			path = change.file,
			lnum = change.line,
		}
	end

	-- Custom previewer showing the change
	local previewer = previewers.new_buffer_previewer({
		title = "Change Preview",
		define_preview = function(self, entry)
			local change = entry.value
			local lines = vim.fn.readfile(change.file)

			if not lines then
				return
			end

			-- Show context around the change
			local start = math.max(1, change.line - 5)
			local stop = math.min(#lines, change.line + 5)
			local preview_lines = {}

			for i = start, stop do
				local prefix = i == change.line and "→ " or "  "
				local line = lines[i]

				if i == change.line and change.new_line_content then
					-- Show old and new
					table.insert(preview_lines, prefix .. "- " .. line)
					table.insert(preview_lines, prefix .. "+ " .. change.new_line_content)
				else
					table.insert(preview_lines, prefix .. line)
				end
			end

			vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, preview_lines)

			-- Highlight the changed line
			-- Create (or reuse) a namespace for diff highlights
			local ns = vim.api.nvim_create_namespace("my_diff_ns")

			---@param bufnr integer
			---@param line integer  -- 0-based
			---@param hl string
			local function highlight_full_line(bufnr, line, hl)
				vim.api.nvim_buf_set_extmark(bufnr, ns, line, 0, {
					hl_group = hl,
					hl_eol = true, -- highlight until end of line
					priority = 100, -- optional, higher wins
				})
			end

			-- original replacements
			highlight_full_line(self.state.bufnr, change.line - start, "DiffDelete")
			highlight_full_line(self.state.bufnr, change.line - start + 1, "DiffAdd")
		end,
	})

	pickers
		.new({}, {
			prompt_title = string.format("Update Requires (%d found)", #changes),
			finder = finders.new_table({
				results = changes,
				entry_maker = entry_maker,
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewer,
			attach_mappings = function(prompt_bufnr, map)
				-- Toggle selection with Tab
				map("i", "<Tab>", function()
					local picker = action_state.get_current_picker(prompt_bufnr)
					local entry = action_state.get_selected_entry()
					if not entry then
						return
					end

					-- Toggle selection state
					selected_items[entry.value] = not selected_items[entry.value]
					-- Build marker
					local marker = selected_items[entry.value] and "[✓] " or "[ ] "
					-- Preserve original display text
					local text = type(entry.display) == "string" and entry.display or entry.ordinal
					-- Overwrite display
					entry.display = marker .. text
					-- Force redraw by refreshing picker
					picker:refresh(picker.finder, { reset_prompt = false })
				end)

				-- Select all with Shift+A
				map("i", "<S-A>", function()
					for _, change in ipairs(changes) do
						selected_items[change] = true
					end
					logger.info("Selected all changes")
				end)

				-- Confirm selection
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)

					-- Collect selected changes
					local selected = {}
					for change, is_selected in pairs(selected_items) do
						if is_selected then
							table.insert(selected, change)
						end
					end

					-- If nothing selected, use current entry
					if #selected == 0 then
						local entry = action_state.get_selected_entry()
						if entry then
							selected = { entry.value }
						end
					end

					on_confirm(selected)
				end)

				return true
			end,
		})
		:find()
end

--- Show FZF-Lua picker (simplified fallback)
---@param changes RequireChange[] List of changes
---@param on_confirm fun(selected: RequireChange[]) Callback
---@return nil
function M.show_fzf(changes, on_confirm)
	local fzf = require("fzf-lua")

	local entries = {}
	for _, change in ipairs(changes) do
		table.insert(
			entries,
			string.format(
				"%s:%d | %s → %s",
				vim.fn.fnamemodify(change.file, ":~:."),
				change.line,
				change.old_require,
				change.new_require
			)
		)
	end

	fzf.fzf_exec(entries, {
		prompt = "Select requires to update> ",
		actions = {
			["default"] = function(selected)
				-- Parse selected entries back to changes
				local selected_changes = {}
				for _, sel in ipairs(selected) do
					local file, line = sel:match("^([^:]+):(%d+)")
					if file and line then
						for _, change in ipairs(changes) do
							if change.file:match(file .. "$") and change.line == tonumber(line) then
								table.insert(selected_changes, change)
								break
							end
						end
					end
				end
				on_confirm(selected_changes)
			end,
		},
		multiselect = true,
	})
end

return M
