---@module 'neotree_fs_refactor.orchestrator'
---@brief Orchestrates the complete refactoring workflow
---@description
--- Coordinates LSP and fallback phases, creates change plans,
--- and manages the overall refactoring process.

local config = require("neotree_fs_refactor.config")
local lsp = require("neotree_fs_refactor.lsp")
local fallback = require("neotree_fs_refactor.fallback")
local utils = require("neotree_fs_refactor.utils")
local notify = require("neotree_fs_refactor.utils.notify")

local M = {}

local str_format = string.format

---Validate filesystem operation
---@param operation Neotree.FSRefactor.FSOperation
---@return boolean valid
---@return string|nil error_message
local function validate_operation(operation)
  if type(operation) ~= "table" then
    return false, "Operation must be a table"
  end

  if not operation.type then
    return false, "Operation type is required"
  end

  local valid_types = { rename = true, move = true, delete = true }
  if not valid_types[operation.type] then
    return false, "Invalid operation type: " .. tostring(operation.type)
  end

  if not operation.old_path or type(operation.old_path) ~= "string" then
    return false, "Operation old_path is required and must be string"
  end

  if operation.type ~= "delete" then
    if not operation.new_path or type(operation.new_path) ~= "string" then
      return false, "Operation new_path is required for non-delete operations"
    end
  end

  if operation.is_directory == nil then
    return false, "Operation is_directory field is required"
  end

  return true, nil
end

---Create a change plan from filesystem operation
---@param operation Neotree.FSRefactor.FSOperation
---@return Neotree.FSRefactor.ChangePlan|nil plan
---@return string|nil error
function M.create_plan(operation)
  -- Validate operation
  local valid, err = validate_operation(operation)
  if not valid then
    return nil, err
  end

  -- Check if old path exists
  if not utils.path_exists(operation.old_path) then
    return nil, "Source path does not exist: " .. operation.old_path
  end

  -- Verify is_directory matches actual filesystem
  local actual_is_dir = utils.is_directory(operation.old_path)
  if actual_is_dir ~= operation.is_directory then
    return nil, str_format(
      "Path type mismatch: expected %s, got %s",
      operation.is_directory and "directory" or "file",
      actual_is_dir and "directory" or "file"
    )
  end

  -- Initialize change plan
  local plan = {
    operation = operation,
    lsp_result = { success = false, edits = {}, errors = {}, servers_contacted = {} },
    fallback_result = nil,
    created_at = os.time(),
    reviewed = false,
  }

  -- Phase 1: Collect LSP edits
  if config.is_lsp_enabled() then
    local level = config.get_notify_level()
    if level <= vim.log.levels.INFO then
      notify.info("Collecting LSP edits...")
    end

    local ok, result = pcall(lsp.collect_edits, operation)
    if ok then
      plan.lsp_result = result

      if #result.edits > 0 then
        if level <= vim.log.levels.INFO then
          notify.info(
            str_format("LSP: Found %d edit(s) from %d server(s)",
              #result.edits,
              #result.servers_contacted
            )
          )
        end
      end
    else
      plan.lsp_result.errors[#plan.lsp_result.errors + 1] = "LSP phase failed: " .. tostring(result)
    end
  end

  -- Phase 2: Fallback search (if enabled and needed)
  if config.is_fallback_enabled() then
    local level = config.get_notify_level()
    if level <= vim.log.levels.INFO then
      notify.info("Performing fallback search...")
    end

    local ok, result = pcall(fallback.search, operation)
    if ok then
      plan.fallback_result = result

      if #result.edits > 0 then
        if level <= vim.log.levels.INFO then
          notify.info(
            str_format("Fallback: Found %d potential edit(s)",
              #result.edits
            )
          )
        end
      end
    else
      if not plan.fallback_result then
        plan.fallback_result = {
          success = false,
          edits = {},
          files_scanned = 0,
          matches_found = 0,
          errors = { "Fallback phase failed: " .. tostring(result) },
        }
      end
    end
  end

  return plan, nil
end

---Execute a change plan
---@param plan Neotree.FSRefactor.ChangePlan
---@param skip_review boolean|nil Skip review step
---@return Neotree.FSRefactor.ApplyResult
function M.execute_plan(plan, skip_review)
  if type(plan) ~= "table" then
    return {
      success = false,
      applied_count = 0,
      failed_count = 0,
      errors = { { message = "Invalid plan" } },
      duration_ms = 0,
    }
  end

  -- Check if review is needed
  if not skip_review and config.should_show_preview() and not plan.reviewed then
    return {
      success = false,
      applied_count = 0,
      failed_count = 0,
      errors = { { message = "Plan must be reviewed before execution" } },
      duration_ms = 0,
    }
  end

  local total_result = {
    success = true,
    applied_count = 0,
    failed_count = 0,
    errors = {},
    duration_ms = 0,
  }

  local start_time = vim.loop.now()

  -- Apply LSP edits
  if plan.lsp_result and #plan.lsp_result.edits > 0 then
    local ok, lsp_result = pcall(lsp.apply_edits, plan.lsp_result)

    if ok then
      total_result.applied_count = total_result.applied_count + lsp_result.applied_count
      total_result.failed_count = total_result.failed_count + lsp_result.failed_count

      for i = 1, #lsp_result.errors do
        total_result.errors[#total_result.errors + 1] = lsp_result.errors[i]
      end

      if not lsp_result.success then
        total_result.success = false
      end
    else
      total_result.success = false
      total_result.errors[#total_result.errors + 1] = {
        message = "LSP apply failed: " .. tostring(lsp_result),
      }
    end
  end

  -- Apply fallback edits
  if plan.fallback_result and #plan.fallback_result.edits > 0 then
    local ok, fallback_result = pcall(fallback.apply_edits, plan.fallback_result)

    if ok then
      total_result.applied_count = total_result.applied_count + fallback_result.applied_count
      total_result.failed_count = total_result.failed_count + fallback_result.failed_count

      for i = 1, #fallback_result.errors do
        total_result.errors[#total_result.errors + 1] = fallback_result.errors[i]
      end

      if not fallback_result.success then
        total_result.success = false
      end
    else
      total_result.success = false
      total_result.errors[#total_result.errors + 1] = {
        message = "Fallback apply failed: " .. tostring(fallback_result),
      }
    end
  end

  total_result.duration_ms = vim.loop.now() - start_time

  -- Notify user of results
  local level = config.get_notify_level()
  if level <= vim.log.levels.INFO then
    if total_result.success then
      notify.info(
        str_format(
          "Refactoring complete: %d changes applied in %.0fms",
          total_result.applied_count,
          total_result.duration_ms
        )
      )
    else
      notify.warn(
        str_format(
          "Refactoring completed with errors: %d applied, %d failed",
          total_result.applied_count,
          total_result.failed_count
        )
      )
    end
  end

  return total_result
end

---Get summary statistics from a change plan
---@param plan Neotree.FSRefactor.ChangePlan
---@return table # Summary with counts and details
function M.get_plan_summary(plan)
  local summary = {
    operation_type = plan.operation.type,
    old_path = plan.operation.old_path,
    new_path = plan.operation.new_path,
    is_directory = plan.operation.is_directory,
    lsp_edits = 0,
    fallback_edits = 0,
    total_edits = 0,
    files_affected = {},
    lsp_servers = {},
    has_errors = false,
    error_messages = {},
  }

  -- Count LSP edits
  if plan.lsp_result then
    summary.lsp_edits = #plan.lsp_result.edits
    summary.lsp_servers = plan.lsp_result.servers_contacted or {}

    if #plan.lsp_result.errors > 0 then
      summary.has_errors = true
      for i = 1, #plan.lsp_result.errors do
        summary.error_messages[#summary.error_messages + 1] = plan.lsp_result.errors[i]
      end
    end

    -- Collect affected files from LSP
    for i = 1, #plan.lsp_result.edits do
      local file = plan.lsp_result.edits[i].file_path
      if not summary.files_affected[file] then
        summary.files_affected[file] = true
      end
    end
  end

  -- Count fallback edits
  if plan.fallback_result then
    summary.fallback_edits = #plan.fallback_result.edits

    if #plan.fallback_result.errors > 0 then
      summary.has_errors = true
      for i = 1, #plan.fallback_result.errors do
        summary.error_messages[#summary.error_messages + 1] = plan.fallback_result.errors[i]
      end
    end

    -- Collect affected files from fallback
    for i = 1, #plan.fallback_result.edits do
      local file = plan.fallback_result.edits[i].file_path
      if not summary.files_affected[file] then
        summary.files_affected[file] = true
      end
    end
  end

  summary.total_edits = summary.lsp_edits + summary.fallback_edits

  -- Convert files_affected to array
  local files = {}
  for file, _ in pairs(summary.files_affected) do
    files[#files + 1] = file
  end
  summary.files_affected = files

  return summary
end

return M
