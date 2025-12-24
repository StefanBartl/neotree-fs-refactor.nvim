---@module 'neotree_fs_refactor.lsp'
---@brief LSP integration for semantic refactoring
---@description
--- Handles communication with LSP servers for rename operations.
--- Uses workspace/willRenameFiles to collect semantic edits.

local config = require("neotree_fs_refactor.config")
local utils = require("neotree_fs_refactor.utils")

local M = {}

local loop = vim.loop

---Convert filesystem operation to LSP FileRename structure
---@param operation Neotree.FSRefactor.FSOperation
---@return table # LSP FileRename object
local function operation_to_file_rename(operation)
  return {
    oldUri = vim.uri_from_fname(operation.old_path),
    newUri = vim.uri_from_fname(operation.new_path or operation.old_path),
  }
end

---Request workspace edits from a single LSP client
---@param client table LSP client
---@param files table[] Array of FileRename objects
---@param timeout integer Timeout in milliseconds
---@return Neotree.FSRefactor.LSPEdit[]|nil edits
---@return string|nil error
local function request_edits_from_client(client, files, timeout)
  if not client or not client.server_capabilities then
    return nil, "Invalid client"
  end

  -- Check if server supports workspace/willRenameFiles
  local caps = client.server_capabilities
  if not caps.workspace or not caps.workspace.fileOperations or not caps.workspace.fileOperations.willRename then
    return nil, "Server does not support willRenameFiles"
  end

  local params = {
    files = files,
  }

  -- Request with timeout
  local result = nil
  local err = nil
  local completed = false

  client.request("workspace/willRenameFiles", params, function(request_err, workspace_edit)
    if request_err then
      err = request_err.message or "Unknown error"
    else
      result = workspace_edit
    end
    completed = true
  end)

  -- Wait for completion with timeout
  local start = loop.now()
  while not completed and (loop.now() - start) < timeout do
    vim.wait(10)
  end

  if not completed then
    return nil, "Request timeout"
  end

  if err then
    return nil, err
  end

  if not result or not result.changes and not result.documentChanges then
    return {}, nil
  end

  -- Convert workspace edit to our format
  local edits = {}

  -- Handle documentChanges (preferred)
  if result.documentChanges then
    for i = 1, #result.documentChanges do
      local doc_change = result.documentChanges[i]
      if doc_change.textDocument and doc_change.edits then
        local file_path = vim.uri_to_fname(doc_change.textDocument.uri)
        edits[#edits + 1] = {
          file_path = file_path,
          changes = doc_change.edits,
          lsp_name = client.name,
        }
      end
    end
  -- Handle changes (legacy)
  elseif result.changes then
    for uri, file_edits in pairs(result.changes) do
      local file_path = vim.uri_to_fname(uri)
      edits[#edits + 1] = {
        file_path = file_path,
        changes = file_edits,
        lsp_name = client.name,
      }
    end
  end

  return edits, nil
end

---Collect edits from all applicable LSP clients
---@param operation Neotree.FSRefactor.FSOperation
---@return Neotree.FSRefactor.LSPResult
function M.collect_edits(operation)
  local result = {
    success = false,
    edits = {},
    errors = {},
    servers_contacted = {},
  }

  if not config.is_lsp_enabled() then
    result.success = true
    return result
  end

  -- Convert operation to LSP format
  local files = { operation_to_file_rename(operation) }

  -- Get all active LSP clients
  local clients = vim.lsp.get_clients()

  if #clients == 0 then
    result.success = true
    return result
  end

  local timeout = config.get("timeout_ms")
  local collected_any = false

  -- Request from each client
  for i = 1, #clients do
    local client = clients[i]
    result.servers_contacted[#result.servers_contacted + 1] = client.name

    local edits, err = request_edits_from_client(client, files, timeout)

    if err then
      result.errors[#result.errors + 1] = string.format("[%s] %s", client.name, err)
    elseif edits then
      -- Merge edits into result
      for j = 1, #edits do
        result.edits[#result.edits + 1] = edits[j]
      end
      collected_any = true
    end
  end

  result.success = #result.errors == 0 or collected_any
  return result
end

---Apply LSP edits to buffers
---@param lsp_result Neotree.FSRefactor.LSPResult
---@return Neotree.FSRefactor.ApplyResult
function M.apply_edits(lsp_result)
  local apply_result = {
    success = true,
    applied_count = 0,
    failed_count = 0,
    errors = {},
    duration_ms = 0,
  }

  local start_time = loop.now()

  if not lsp_result.edits or #lsp_result.edits == 0 then
    apply_result.duration_ms = loop.now() - start_time
    return apply_result
  end

  -- Group edits by file
  local edits_by_file = {}
  for i = 1, #lsp_result.edits do
    local edit = lsp_result.edits[i]
    if not edits_by_file[edit.file_path] then
      edits_by_file[edit.file_path] = {}
    end

    for j = 1, #edit.changes do
      edits_by_file[edit.file_path][#edits_by_file[edit.file_path] + 1] = edit.changes[j]
    end
  end

  -- Apply edits file by file
  for file_path, file_edits in pairs(edits_by_file) do
    -- Load buffer if not loaded
    local buf = nil

    -- Check if file is already open in a buffer
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if utils.is_valid_buffer(b) then
        local buf_name = vim.api.nvim_buf_get_name(b)
        if buf_name == file_path then
          buf = b
          break
        end
      end
    end

    -- If not found, create a new buffer
    if not buf then
      buf = vim.fn.bufadd(file_path)
      vim.fn.bufload(buf)
    end

    if not utils.is_valid_buffer(buf) then
      apply_result.failed_count = apply_result.failed_count + 1
      apply_result.errors[#apply_result.errors + 1] = {
        file = file_path,
        message = "Failed to load buffer",
      }
      apply_result.success = false
      goto continue
    end

    -- Sort edits by position (reverse order to avoid offset issues)
    table.sort(file_edits, function(a, b)
      if a.range.start.line ~= b.range.start.line then
        return a.range.start.line > b.range.start.line
      end
      return a.range.start.character > b.range.start.character
    end)

    -- Apply each edit
    for i = 1, #file_edits do
      local edit = file_edits[i]
      local start_line = edit.range.start.line
      local end_line = edit.range["end"].line
      local start_char = edit.range.start.character
      local end_char = edit.range["end"].character

      -- Get current line content
      local lines = utils.get_buf_lines(buf, start_line, end_line + 1)
      if not lines then
        apply_result.failed_count = apply_result.failed_count + 1
        apply_result.errors[#apply_result.errors + 1] = {
          file = file_path,
          line = start_line + 1,
          message = "Failed to read buffer lines",
        }
        apply_result.success = false
        goto continue_edit
      end

      -- Calculate new text
      local new_lines = vim.split(edit.newText, "\n", { plain = true })

      -- Handle single-line edit
      if #lines == 1 then
        local line = lines[1]
        local before = line:sub(1, start_char)
        local after = line:sub(end_char + 1)

        if #new_lines == 1 then
          new_lines[1] = before .. new_lines[1] .. after
        else
          new_lines[1] = before .. new_lines[1]
          new_lines[#new_lines] = new_lines[#new_lines] .. after
        end
      end

      -- Apply the edit
      local ok = utils.set_buf_lines(buf, start_line, end_line + 1, new_lines)

      if ok then
        apply_result.applied_count = apply_result.applied_count + 1
      else
        apply_result.failed_count = apply_result.failed_count + 1
        apply_result.errors[#apply_result.errors + 1] = {
          file = file_path,
          line = start_line + 1,
          message = "Failed to apply edit",
        }
        apply_result.success = false
      end

      ::continue_edit::
    end

    -- Save buffer
    vim.api.nvim_buf_call(buf, function()
      vim.cmd("silent! write")
    end)

    ::continue::
  end

  apply_result.duration_ms = loop.now() - start_time
  return apply_result
end

return M
