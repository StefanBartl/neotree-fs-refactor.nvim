---@module 'neotree_fs_refactor.ui.preview'
---@brief Preview UI for reviewing changes before applying
---@description
--- Displays a split window showing all proposed changes with
--- diff-style highlighting and interactive confirmation.

local utils = require("neotree_fs_refactor.utils")

local M = {}

---@type Neotree.FSRefactor.PreviewState|nil
local state = nil

---Convert change plan to preview items
---@param plan Neotree.FSRefactor.ChangePlan
---@return Neotree.FSRefactor.PreviewItem[]
local function plan_to_preview_items(plan)
  local items = {}

  -- Add LSP edits
  if plan.lsp_result and plan.lsp_result.edits then
    for i = 1, #plan.lsp_result.edits do
      local lsp_edit = plan.lsp_result.edits[i]

      for j = 1, #lsp_edit.changes do
        local change = lsp_edit.changes[j]

        -- Get old content
        local start_line = change.range.start.line
        local end_line = change.range["end"].line

        -- Read file to get context
        local old_lines = {}
        local file_handle = io.open(lsp_edit.file_path, "r")
        if file_handle then
          local line_num = 0
          for line in file_handle:lines() do
            if line_num >= start_line and line_num <= end_line then
              old_lines[#old_lines + 1] = line
            end
            line_num = line_num + 1
          end
          file_handle:close()
        end

        items[#items + 1] = {
          file_path = lsp_edit.file_path,
          edit_type = "lsp",
          old_content = table.concat(old_lines, "\n"),
          new_content = change.newText,
          line_number = start_line + 1,
          confidence = nil,
        }
      end
    end
  end

  -- Add fallback edits
  if plan.fallback_result and plan.fallback_result.edits then
    for i = 1, #plan.fallback_result.edits do
      local fb_edit = plan.fallback_result.edits[i]

      items[#items + 1] = {
        file_path = fb_edit.file_path,
        edit_type = "fallback",
        old_content = fb_edit.old_text,
        new_content = fb_edit.new_text,
        line_number = fb_edit.line_number,
        confidence = fb_edit.confidence,
      }
    end
  end

  return items
end

---Create preview buffer with formatted content
---@param items Neotree.FSRefactor.PreviewItem[]
---@return integer|nil buf
---@return string|nil error
local function create_preview_buffer(items)
  local buf = vim.api.nvim_create_buf(false, true)
  if not buf or buf == 0 then
    return nil, "Failed to create buffer"
  end

  -- Set buffer options
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "diff", { buf = buf })

  -- Build content
  local lines = {}
  lines[#lines + 1] = "=== Refactoring Preview ==="
  lines[#lines + 1] = string.format("Total changes: %d", #items)
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Press <CR> to apply changes, <Esc> to cancel"
  lines[#lines + 1] = string.rep("=", 50)
  lines[#lines + 1] = ""

  for i = 1, #items do
    local item = items[i]

    -- File header
    lines[#lines + 1] = string.format("--- %s:%d (%s)",
      item.file_path,
      item.line_number,
      item.edit_type
    )

    if item.confidence then
      lines[#lines + 1] = string.format("    Confidence: %s", item.confidence)
    end

    -- Show diff
    lines[#lines + 1] = string.format("- %s", item.old_content)
    lines[#lines + 1] = string.format("+ %s", item.new_content)
    lines[#lines + 1] = ""
  end

  -- Set content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  return buf, nil
end

---Open preview window
---@param buf integer Buffer handle
---@return integer|nil win
---@return string|nil error
local function open_preview_window(buf)
  if not utils.is_valid_buffer(buf) then
    return nil, "Invalid buffer"
  end

  -- Calculate window dimensions
  local ui = vim.api.nvim_list_uis()[1]
  if not ui then
    return nil, "No UI available"
  end

  local width = math.floor(ui.width * 0.8)
  local height = math.floor(ui.height * 0.8)
  local row = math.floor((ui.height - height) / 2)
  local col = math.floor((ui.width - width) / 2)

  -- Open floating window
  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Refactor Preview ",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, win_opts)
  if not win or win == 0 then
    return nil, "Failed to open window"
  end

  -- Set window options
  vim.api.nvim_set_option_value("number", false, { win = win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = win })
  vim.api.nvim_set_option_value("cursorline", true, { win = win })

  return win, nil
end

---Setup keymaps for preview window
---@param buf integer Buffer handle
---@param on_confirm function Callback on confirmation
---@param on_cancel function Callback on cancel
local function setup_keymaps(buf, on_confirm, on_cancel)
  if not utils.is_valid_buffer(buf) then
    return
  end

  local opts = { buffer = buf, noremap = true, silent = true }

  -- Confirm
  vim.keymap.set("n", "<CR>", function()
    on_confirm()
  end, opts)

  -- Cancel
  vim.keymap.set("n", "<Esc>", function()
    on_cancel()
  end, opts)

  vim.keymap.set("n", "q", function()
    on_cancel()
  end, opts)

  -- Navigation
  vim.keymap.set("n", "j", "j", opts)
  vim.keymap.set("n", "k", "k", opts)
  vim.keymap.set("n", "<Down>", "j", opts)
  vim.keymap.set("n", "<Up>", "k", opts)
end

---Show preview for a change plan
---@param plan Neotree.FSRefactor.ChangePlan
---@param callback function Callback with (confirmed: boolean)
---@return boolean success
---@return string|nil error
function M.show_preview(plan, callback)
  if type(plan) ~= "table" then
    return false, "Invalid plan"
  end

  if type(callback) ~= "function" then
    return false, "Invalid callback"
  end

  -- Convert plan to preview items
  local items = plan_to_preview_items(plan)

  if #items == 0 then
    callback(true) -- No changes, auto-confirm
    return true, nil
  end

  -- Create preview buffer
  local buf, buf_err = create_preview_buffer(items)
  if not buf then
    return false, buf_err or "Failed to create preview buffer"
  end

  -- Open window
  local win, win_err = open_preview_window(buf)
  if not win then
    if utils.is_valid_buffer(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    return false, win_err or "Failed to open preview window"
  end

  -- Initialize state
  state = {
    items = items,
    current_index = 1,
    buf = buf,
    win = win,
    confirmed = false,
  }

  -- Setup keymaps
  setup_keymaps(buf, function()
    -- Confirm
    state.confirmed = true
    M.close_preview()
    callback(true)
  end, function()
    -- Cancel
    state.confirmed = false
    M.close_preview()
    callback(false)
  end)

  return true, nil
end

---Close preview window and cleanup
function M.close_preview()
  if not state then
    return
  end

  -- Close window
  if state.win and utils.is_valid_window(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end

  -- Delete buffer
  if state.buf and utils.is_valid_buffer(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end

  state = nil
end

---Check if preview is currently open
---@return boolean
function M.is_preview_open()
  return state ~= nil
end

return M
