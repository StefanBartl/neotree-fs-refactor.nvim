---@module 'neotree_fs_refactor.fallback'
---@brief Text-based fallback search for path references
---@description
--- Implements fallback search using ripgrep or native Lua search
--- when LSP cannot provide semantic edits.

local config = require("neotree_fs_refactor.config")
local utils = require("neotree_fs_refactor.utils")

local M = {}

local loop = vim.loop

---Search using ripgrep
---@param pattern string Pattern to search
---@param cwd string Working directory
---@param ignore_patterns string[] Patterns to ignore
---@return Neotree.FSRefactor.PathReference[] references
---@return string|nil error
local function search_with_ripgrep(pattern, cwd, ignore_patterns)
  local refs = {}

  -- Build ripgrep command
  local cmd = { "rg", "--json", "--case-sensitive", "--line-number", "--column" }

  -- Add ignore patterns
  for i = 1, #ignore_patterns do
    cmd[#cmd + 1] = "--glob"
    cmd[#cmd + 1] = "!" .. ignore_patterns[i]
  end

  -- Add pattern and cwd
  cmd[#cmd + 1] = "--"
  cmd[#cmd + 1] = pattern
  cmd[#cmd + 1] = cwd

  -- Execute ripgrep
  local output = {}
  local job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        for i = 1, #data do
          if data[i] ~= "" then
            output[#output + 1] = data[i]
          end
        end
      end
    end,
  })

  if job_id <= 0 then
    return refs, "Failed to start ripgrep"
  end

  -- Wait for completion
  local timeout = config.get("timeout_ms")
  local wait_result = vim.fn.jobwait({ job_id }, timeout)

  if wait_result[1] == -1 then
    vim.fn.jobstop(job_id)
    return refs, "Ripgrep timeout"
  end

  -- Parse JSON output
  for i = 1, #output do
    local ok, data = pcall(vim.json.decode, output[i])
    if ok and data.type == "match" then
      local match_data = data.data
      refs[#refs + 1] = {
        file_path = utils.to_absolute(match_data.path.text) or match_data.path.text,
        line_number = match_data.line_number,
        column_start = match_data.submatches[1].start,
        column_end = match_data.submatches[1]["end"],
        matched_text = match_data.submatches[1].match.text,
        context_line = match_data.lines.text,
      }
    end
  end

  return refs, nil
end

---Search using native Lua (slower, for fallback)
---@param pattern string Pattern to search
---@param cwd string Working directory
---@param ignore_patterns string[] Patterns to ignore
---@return Neotree.FSRefactor.PathReference[] references
---@return string|nil error
local function search_native(pattern, cwd, ignore_patterns)
  local refs = {}

  -- Escape pattern for Lua pattern matching
  local escaped = utils.escape_pattern(pattern)

  -- Find all files in cwd
  local files = {}
  local max_size = config.get("max_file_size_kb")

  local function scan_dir(dir)
    local handle = loop.fs_scandir(dir)
    if not handle then
      return
    end

    while true do
      local name, type = loop.fs_scandir_next(handle)
      if not name then
        break
      end

      local full_path = dir .. "/" .. name

      -- Check if should ignore
      if utils.should_ignore(full_path, ignore_patterns) then
        goto continue
      end

      if type == "directory" then
        scan_dir(full_path)
      elseif type == "file" then
        -- Check file size
        local size = utils.get_file_size_kb(full_path)
        if size and size <= max_size then
          files[#files + 1] = full_path
        end
      end

      ::continue::
    end
  end

  scan_dir(cwd)

  -- Search in each file
  for i = 1, #files do
    local file_path = files[i]

    -- Read file
    local fd = loop.fs_open(file_path, "r", 438)
    if not fd then
      goto continue_file
    end

    local stat = loop.fs_fstat(fd)
    if not stat then
      loop.fs_close(fd)
      goto continue_file
    end

    local content = loop.fs_read(fd, stat.size, 0)
    loop.fs_close(fd)

    if not content then
      goto continue_file
    end

    -- Search line by line
    local lines = vim.split(content, "\n", { plain = true })
    for line_num = 1, #lines do
      local line = lines[line_num]
      local start_pos = 1

      while true do
        local match_start, match_end = line:find(escaped, start_pos, true)
        if not match_start then
          break
        end

        refs[#refs + 1] = {
          file_path = file_path,
          line_number = line_num,
          column_start = match_start - 1, -- 0-indexed
          column_end = match_end,
          matched_text = line:sub(match_start, match_end),
          context_line = line,
        }

        start_pos = match_end + 1
      end
    end

    ::continue_file::
  end

  return refs, nil
end

---Build search patterns from filesystem operation
---@param operation Neotree.FSRefactor.FSOperation
---@return string[] patterns
local function build_search_patterns(operation)
  local patterns = {}

  -- Add old path as-is
  patterns[#patterns + 1] = operation.old_path

  -- Add basename for import-like patterns
  local basename = utils.basename(operation.old_path)
  if basename and basename ~= "" then
    patterns[#patterns + 1] = basename
  end

  -- Add relative patterns from common base directories
  local cwd = vim.fn.getcwd()
  local rel = utils.relative_path(cwd, operation.old_path)
  if rel and rel ~= operation.old_path then
    patterns[#patterns + 1] = rel
  end

  return patterns
end

---Convert path references to fallback edits
---@param refs Neotree.FSRefactor.PathReference[]
---@param operation Neotree.FSRefactor.FSOperation
---@return Neotree.FSRefactor.FallbackEdit[]
local function references_to_edits(refs, operation)
  local edits = {}

  for i = 1, #refs do
    local ref = refs[i]

    -- Calculate new text
    local old_text = ref.matched_text
    local new_text = old_text:gsub(
      utils.escape_pattern(operation.old_path),
      operation.new_path or ""
    )

    -- Determine confidence
    local confidence = "medium"

    -- High confidence if exact match
    if old_text == operation.old_path then
      confidence = "high"
    end

    -- Low confidence if partial match only
    if old_text:find(operation.old_path, 1, true) and old_text ~= operation.old_path then
      confidence = "low"
    end

    edits[#edits + 1] = {
      file_path = ref.file_path,
      line_number = ref.line_number,
      old_text = old_text,
      new_text = new_text,
      confidence = confidence,
    }
  end

  return edits
end

---Perform fallback search
---@param operation Neotree.FSRefactor.FSOperation
---@return Neotree.FSRefactor.FallbackResult
function M.search(operation)
  local result = {
    success = false,
    edits = {},
    files_scanned = 0,
    matches_found = 0,
    errors = {},
  }

  if not config.is_fallback_enabled() then
    result.success = true
    return result
  end

  local fallback_cfg = config.get("fallback")
  local cwd = vim.fn.getcwd()
  local ignore = config.get("ignore_patterns")

  -- Build search patterns
  local patterns = build_search_patterns(operation)
  local all_refs = {}

  -- Search for each pattern
  for i = 1, #patterns do
    local pattern = patterns[i]
    local refs, err

    if fallback_cfg.tool == "ripgrep" and vim.fn.executable("rg") == 1 then
      refs, err = search_with_ripgrep(pattern, cwd, ignore)
    else
      refs, err = search_native(pattern, cwd, ignore)
    end

    if err then
      result.errors[#result.errors + 1] = string.format("Pattern '%s': %s", pattern, err)
    elseif refs then
      for j = 1, #refs do
        all_refs[#all_refs + 1] = refs[j]
      end
    end
  end

  result.matches_found = #all_refs

  -- Convert references to edits
  result.edits = references_to_edits(all_refs, operation)

  -- Filter by confidence threshold
  local threshold = fallback_cfg.confidence_threshold
  local confidence_order = { low = 1, medium = 2, high = 3 }
  local min_level = confidence_order[threshold] or 2

  local filtered_edits = {}
  for i = 1, #result.edits do
    local edit = result.edits[i]
    if confidence_order[edit.confidence] >= min_level then
      filtered_edits[#filtered_edits + 1] = edit
    end
  end

  result.edits = filtered_edits
  result.success = #result.errors == 0 or #result.edits > 0

  return result
end

---Apply fallback edits to files
---@param fallback_result Neotree.FSRefactor.FallbackResult
---@return Neotree.FSRefactor.ApplyResult
function M.apply_edits(fallback_result)
  local apply_result = {
    success = true,
    applied_count = 0,
    failed_count = 0,
    errors = {},
    duration_ms = 0,
  }

  local start_time = loop.now()

  if not fallback_result.edits or #fallback_result.edits == 0 then
    apply_result.duration_ms = loop.now() - start_time
    return apply_result
  end

  -- Group edits by file
  local edits_by_file = {}
  for i = 1, #fallback_result.edits do
    local edit = fallback_result.edits[i]
    if not edits_by_file[edit.file_path] then
      edits_by_file[edit.file_path] = {}
    end
    edits_by_file[edit.file_path][#edits_by_file[edit.file_path] + 1] = edit
  end

  -- Apply edits file by file
  for file_path, file_edits in pairs(edits_by_file) do
    -- Load buffer
    local buf = vim.fn.bufadd(file_path)
    vim.fn.bufload(buf)

    if not utils.is_valid_buffer(buf) then
      apply_result.failed_count = apply_result.failed_count + #file_edits
      apply_result.errors[#apply_result.errors + 1] = {
        file = file_path,
        message = "Failed to load buffer",
      }
      apply_result.success = false
      goto continue
    end

    -- Sort by line number (descending)
    table.sort(file_edits, function(a, b)
      return a.line_number > b.line_number
    end)

    -- Apply each edit
    for i = 1, #file_edits do
      local edit = file_edits[i]
      local line_num = edit.line_number - 1 -- 0-indexed

      local lines = utils.get_buf_lines(buf, line_num, line_num + 1)
      if not lines or #lines == 0 then
        apply_result.failed_count = apply_result.failed_count + 1
        goto continue_edit
      end

      local line = lines[1]
      local new_line = line:gsub(utils.escape_pattern(edit.old_text), edit.new_text, 1)

      local ok = utils.set_buf_lines(buf, line_num, line_num + 1, { new_line })
      if ok then
        apply_result.applied_count = apply_result.applied_count + 1
      else
        apply_result.failed_count = apply_result.failed_count + 1
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
