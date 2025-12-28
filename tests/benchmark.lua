---@module 'tests.benchmark'
---@brief Performance benchmarking suite
---@description
--- Benchmarks for comparing standard vs optimized implementations.

local M = {}

--- Create test directory structure with files
---@param base_dir string Base directory
---@param num_files integer Number of files to create
---@param requires_per_file integer Number of requires per file
---@return string[] List of created files
local function create_test_files(base_dir, num_files, requires_per_file)
  vim.fn.mkdir(base_dir, "p")

  local files = {}
  for i = 1, num_files do
    local file_path = base_dir .. "/file_" .. i .. ".lua"
    local lines = {}

    for j = 1, requires_per_file do
      table.insert(lines, string.format('local mod%d = require("test.module%d")', j, j))
    end

    table.insert(lines, "")
    table.insert(lines, "return {}")

    vim.fn.writefile(lines, file_path)
    files[#files + 1] = file_path
  end

  return files
end

--- Benchmark scanner implementation
---@param name string Benchmark name
---@param scanner_module string Module name
---@param scan_function string Function name
---@param test_dir string Test directory
---@param iterations integer Number of iterations
---@return table Results
local function benchmark_scanner(name, scanner_module, scan_function, test_dir, iterations)
  local scanner = require(scanner_module)
  local cache = require("neotree-fs-refactor.cache")

  local times = {}

  for iter = 1, iterations do
    -- Create fresh cache
    local test_cache = cache.create_cache(test_dir)
    cache._current_cache = test_cache

    -- Warm up
    if iter == 1 then
      collectgarbage("collect")
      vim.wait(100)
    end

    -- Measure
    local start_time = vim.loop.hrtime()
    local completed = false

    scanner[scan_function](test_dir, test_cache, function()
      local end_time = vim.loop.hrtime()
      local elapsed = (end_time - start_time) / 1e6 -- Convert to milliseconds
      times[#times + 1] = elapsed
      completed = true
    end)

    -- Wait for completion (max 30 seconds)
    local timeout = 30000
    local waited = 0
    while not completed and waited < timeout do
      vim.wait(100)
      waited = waited + 100
    end

    if not completed then
      print(string.format("  [%s] Iteration %d TIMEOUT", name, iter))
      break
    end
  end

  -- Calculate statistics
  table.sort(times)
  local count = #times
  local sum = 0
  for _, t in ipairs(times) do
    sum = sum + t
  end

  return {
    name = name,
    times = times,
    mean = sum / count,
    median = times[math.ceil(count / 2)],
    min = times[1],
    max = times[count],
    count = count,
  }
end

--- Run full benchmark suite
---@param config table Benchmark configuration
---@return nil
function M.run(config)
  config = vim.tbl_extend("force", {
    test_dir = "/tmp/refactor_benchmark",
    num_files = 100,
    requires_per_file = 10,
    iterations = 5,
  }, config or {})

  print("\n=== Neotree-FS-Refactor Benchmark ===")
  print(string.format("Files: %d, Requires/File: %d, Iterations: %d\n",
    config.num_files, config.requires_per_file, config.iterations))

  -- Setup
  vim.fn.delete(config.test_dir, "rf")
  local files = create_test_files(
    config.test_dir,
    config.num_files,
    config.requires_per_file
  )
  print(string.format("Created %d test files\n", #files))

  -- Initialize logger (silent for benchmarks)
  package.loaded["neotree-fs-refactor.utils.logger"] = {
    debug = function() end,
    info = function() end,
    warn = function() end,
    error = function() end,
    setup = function() end,
  }

  -- Benchmark: Standard Scanner
  print("Running: Standard Async Scanner...")
  local result_standard = benchmark_scanner(
    "Standard",
    "neotree-fs-refactor.cache.scanner_async",
    "scan_directory",
    config.test_dir,
    config.iterations
  )

  -- Benchmark: Optimized Scanner
  print("Running: Optimized Scanner...")
  local result_optimized = benchmark_scanner(
    "Optimized",
    "neotree-fs-refactor.cache.scanner_optimized",
    "scan_directory_optimized",
    config.test_dir,
    config.iterations
  )

  -- Print results
  print("\n=== Results ===\n")

  local function print_result(result)
    print(string.format("  %s:", result.name))
    print(string.format("    Mean:   %.2f ms", result.mean))
    print(string.format("    Median: %.2f ms", result.median))
    print(string.format("    Min:    %.2f ms", result.min))
    print(string.format("    Max:    %.2f ms", result.max))
    print()
  end

  print_result(result_standard)
  print_result(result_optimized)

  -- Comparison
  local speedup = result_standard.mean / result_optimized.mean
  print(string.format("Speedup: %.2fx (optimized is %.1f%% faster)\n",
    speedup, (speedup - 1) * 100))

  -- Cleanup
  vim.fn.delete(config.test_dir, "rf")

  return {
    standard = result_standard,
    optimized = result_optimized,
    speedup = speedup,
  }
end

--- Quick benchmark (fewer iterations)
function M.quick()
  return M.run({
    num_files = 50,
    requires_per_file = 5,
    iterations = 3,
  })
end

--- Full benchmark (more files, more iterations)
function M.full()
  return M.run({
    num_files = 500,
    requires_per_file = 20,
    iterations = 10,
  })
end

--- Run benchmark from command line
if vim.fn.argc() > 0 and vim.fn.argv(0) == "benchmark" then
  M.quick()
end

return M
