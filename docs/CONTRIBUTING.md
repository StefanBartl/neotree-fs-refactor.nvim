# Contributing to neotree-fs-refactor.nvim

Thank you for your interest in contributing! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Architecture Overview](#architecture-overview)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Issue Guidelines](#issue-guidelines)

---

## Code of Conduct

This project follows a simple principle: **Be respectful and constructive.**

- Use welcoming and inclusive language
- Respect differing viewpoints and experiences
- Accept constructive criticism gracefully
- Focus on what's best for the community

---

## Getting Started

### Prerequisites

- Neovim >= 0.9.0
- Git
- Basic understanding of Lua and Neovim plugin development
- Familiarity with LSP concepts
- (Optional) Neo-tree.nvim for testing

---

### Development Dependencies

```bash
# Clone the repository
git clone https://github.com/your-username/neotree-fs-refactor.nvim
cd neotree-fs-refactor.nvim

# Install development tools (optional)
# - lua-language-server for LSP support
# - stylua for code formatting
# - luacheck for linting
```

---

## Development Setup

### 1. Configure Neovim for Development

Add to your Neovim config:

```lua
-- Use local development version
vim.opt.runtimepath:prepend("~/path/to/neotree-fs-refactor.nvim")

require("neotree_fs_refactor").setup({
  notify_level = "debug", -- See all debug messages
})
```

---

### 2. Enable Lua Language Server

Create `.luarc.json` in project root:

```json
{
  "diagnostics.globals": ["vim"],
  "workspace.library": [
    "$VIMRUNTIME/lua",
    "${3rd}/luv/library"
  ],
  "hint.enable": true
}
```

---

### 3. Run Health Check

```vim
:checkhealth neotree-fs-refactor
```

---

## Architecture Overview

The plugin follows a layered architecture:

```
┌─────────────────────────────────────┐
│     Neo-tree Integration Layer      │  (neotree.lua)
├─────────────────────────────────────┤
│   Orchestration & Workflow Layer    │  (orchestrator.lua)
├──────────────┬──────────────────────┤
│  LSP Layer   │   Fallback Layer     │  (lsp.lua, fallback.lua)
├──────────────┴──────────────────────┤
│        UI & Preview Layer           │  (ui/preview.lua)
├─────────────────────────────────────┤
│    Config & Utils Foundation        │  (config.lua, utils.lua)
└─────────────────────────────────────┘
```

---

### Module Responsibilities

- **neotree.lua**: Event hooks, event-to-operation conversion
- **orchestrator.lua**: Plan creation, phase coordination, execution
- **lsp.lua**: LSP client communication, edit collection/application
- **fallback.lua**: Text search (ripgrep/native), edit discovery
- **ui/preview.lua**: Interactive preview window, user confirmation
- **config.lua**: Configuration management, validation
- **utils.lua**: Pure utility functions, path operations

---

## Coding Standards

We strictly follow `Arch&Coding-Regeln.md`. Key principles:

---

### 1. Safety & Error Handling

```lua
-- ✅ Good: Wrapped in pcall
local ok, result = pcall(vim.api.nvim_buf_get_lines, buf, 0, -1, false)
if not ok then
  return nil, "Failed to read buffer"
end

-- ❌ Bad: No error handling
local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
```

---

### 2. Type Guards

```lua
-- ✅ Good: Validate inputs
function M.process(data)
  if type(data) ~= "table" then
    return nil, "Invalid data type"
  end

  if not data.required_field then
    return nil, "Missing required field"
  end

  -- Process...
end

-- ❌ Bad: Assume inputs are valid
function M.process(data)
  return data.required_field:upper() -- Will crash if nil
end
```

---

### 3. Buffer/Window Validation

```lua
-- ✅ Good: Check validity
if not vim.api.nvim_buf_is_valid(buf) then
  return
end

-- Do something with buf
vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

-- ❌ Bad: Use without checking
vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
```

---

### 4. Documentation

```lua
---Process a filesystem operation
---@param operation Neotree.FSRefactor.FSOperation Operation to process
---@return Neotree.FSRefactor.ChangePlan|nil plan Generated change plan
---@return string|nil error Error message if failed
function M.create_plan(operation)
  -- Implementation
end
```

---

### 5. Pure Functions Preferred

```lua
-- ✅ Good: Pure function
function M.calculate_path(base, target)
  -- No side effects, deterministic
  return path_logic(base, target)
end

-- ❌ Bad: Modifies global state
function M.calculate_path(base, target)
  _G.last_calculated = result
  return result
end
```

---

## Testing

### Running Tests

```lua
-- In Neovim
:luafile tests/config_test.lua
:luafile tests/utils_test.lua
:luafile tests/integration_test.lua
```

---

### Writing Tests

```lua
local test_utils = require("tests.test_utils")

local tests = {}

function tests.test_my_feature()
  local result = my_module.my_function()
  test_utils.assert_not_nil(result, "Should return result")
  test_utils.assert_equal(result.status, "success", "Should succeed")
end

test_utils.run_suite("My Feature Tests", tests)
```

---

### Test Coverage Requirements

- All public functions must have tests
- Edge cases must be covered (nil, empty, invalid inputs)
- Error paths must be tested
- Buffer/window operations must be validated

---

## Pull Request Process

### 1. Before Submitting

- [ ] Run `:checkhealth neotree-fs-refactor`
- [ ] Run all tests
- [ ] Format code with `stylua` (if available)
- [ ] Check for Lua syntax errors
- [ ] Update documentation if needed
- [ ] Add tests for new features

---

### 2. PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- Tested on Neovim version: X.X.X
- Tested with LSP servers: [list]
- Manual testing steps: [describe]

## Checklist
- [ ] Code follows project standards
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] Health check passes
```

---

### 3. Review Process

1. Automated checks (if configured)
2. Code review by maintainer
3. Address feedback
4. Final approval and merge

---

## Issue Guidelines

### Bug Reports

```markdown
**Describe the bug**
Clear description of the issue

**To Reproduce**
1. Steps to reproduce
2. ...

**Expected behavior**
What should happen

**Environment**
- Neovim version:
- Plugin version:
- LSP servers:
- OS:

**Additional context**
- Error messages
- `:checkhealth neotree-fs-refactor` output
- Screenshots (if applicable)
```

---

### Feature Requests

```markdown
**Is your feature request related to a problem?**
Description of the problem

**Describe the solution you'd like**
Clear description of desired behavior

**Describe alternatives you've considered**
Alternative approaches

**Additional context**
Use cases, examples, mockups
```

---

## Development Tips

### Debugging

```lua
-- Enable debug logging
require("neotree_fs_refactor").setup({
  notify_level = "debug"
})

-- Add debug prints
vim.notify(vim.inspect(data), vim.log.levels.DEBUG)

-- Check LSP logs
:LspLog
```

---

### Common Pitfalls

1. **Forgetting to validate handles**: Always check `nvim_buf_is_valid()` / `nvim_win_is_valid()`
2. **Not using pcall**: Wrap API calls that might fail
3. **Modifying tables during iteration**: Create a copy first
4. **Hardcoded paths**: Use `vim.fn.getcwd()` and relative paths

---

### Performance Considerations

- Pre-allocate tables when size is known: `{ [N] = 0 }`
- Use `table.concat()` for string building, not `..`
- Cache repeated calculations
- Debounce I/O operations

---

## Resources

- [Neovim API Documentation](https://neovim.io/doc/user/api.html)
- [Lua 5.1 Reference](https://www.lua.org/manual/5.1/)
- [LSP Specification](https://microsoft.github.io/language-server-protocol/)
- [Neo-tree Documentation](https://github.com/nvim-neo-tree/neo-tree.nvim)

---

## Questions?

- Open an issue for questions
- Check existing issues first
- Be patient and respectful

Thank you for contributing! 🎉

---
