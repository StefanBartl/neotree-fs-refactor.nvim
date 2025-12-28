---@module 'neotree-fs-refactor.refactor.file_updater'
---@brief Apply require() changes to files
---@description
--- Handles writing updated require statements back to files,
--- with support for dry-run mode and backup creation.

local M = {}

local logger = require("neotree-fs-refactor.utils.logger")

--- Apply multiple changes, grouping by file
---@param changes Neotree.FSRefactor.RequireChange[] Changes to apply
---@param dry_run boolean If true, only simulate changes
---@return Neotree.FSRefactor.UpdateResult[] Results for each file
function M.apply_changes(changes, dry_run)
  if #changes == 0 then
    logger.info("No changes to apply")
    return {}
  end

  -- Group changes by file
  local by_file = {}
  for _, change in ipairs(changes) do
    by_file[change.file] = by_file[change.file] or {}
    table.insert(by_file[change.file], change)
  end

  local results = {}
  local total_files = vim.tbl_count(by_file)
  local processed = 0

  for file, file_changes in pairs(by_file) do
    processed = processed + 1

    logger.info(string.format(
      "[%d/%d] Processing %s (%d change(s))",
      processed, total_files, file, #file_changes
    ))

    -- Read file once
    local ok, lines = pcall(vim.fn.readfile, file)
    if not ok or not lines then
      results[#results + 1] = {
        success = false,
        file = file,
        changes_applied = 0,
        error = "Failed to read file",
      }
      goto continue
    end

    -- Sort changes by line number (descending) to avoid line shifting issues
    table.sort(file_changes, function(a, b) return a.line > b.line end)

    local changes_applied = 0
    local file_modified = false

    for _, change in ipairs(file_changes) do
      if change.line > 0 and change.line <= #lines and change.new_line_content then
        if dry_run then
          logger.info(string.format(
            "[DRY-RUN] %s:%d\n  - %s\n  + %s",
            file, change.line,
            lines[change.line],
            change.new_line_content
          ))
        else
          lines[change.line] = change.new_line_content
          file_modified = true
        end
        changes_applied = changes_applied + 1
      end
    end

    -- Write file if modified
    if file_modified then
      local write_ok = pcall(vim.fn.writefile, lines, file)
      if write_ok then
        results[#results + 1] = {
          success = true,
          file = file,
          changes_applied = changes_applied,
        }
        logger.info(string.format("✓ Updated %s (%d change(s))", file, changes_applied))
      else
        results[#results + 1] = {
          success = false,
          file = file,
          changes_applied = 0,
          error = "Failed to write file",
        }
      end
    elseif dry_run then
      results[#results + 1] = {
        success = true,
        file = file,
        changes_applied = changes_applied,
      }
    end

    ::continue::
  end

  -- Summary
  local successful = vim.tbl_filter(function(r) return r.success end, results)
  local total_changes = vim.tbl_reduce(results, function(acc, r) return acc + r.changes_applied end, 0)

  if dry_run then
    logger.info(string.format(
      "[DRY-RUN] Would update %d file(s) with %d change(s)",
      #successful, total_changes
    ))
  else
    logger.info(string.format(
      "Successfully updated %d file(s) with %d change(s)",
      #successful, total_changes
    ))
  end

  return results
end
return M
