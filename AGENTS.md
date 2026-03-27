# Agent Instructions for fossil.nvim

Welcome! You are operating in `fossil.nvim`, a Neovim plugin written in Lua that provides integration with the Fossil SCM, heavily inspired by `vim-fugitive`. Please follow these guidelines to maintain a clean, consistent, and well-tested codebase.

## 1. Build, Lint, and Test Commands

Since this is a Neovim plugin written in Lua, there is no traditional compilation step. Changes take effect immediately upon reloading Neovim.

### Linting and Formatting
- **Formatting**: We use `stylua` for code formatting. Always run this before committing.
  ```bash
  stylua lua/ plugin/ tests/
  ```
- **Linting**: We recommend `luacheck` for static analysis to catch undefined globals and unused variables.
  ```bash
  luacheck lua/ plugin/ tests/
  ```
- **Type Checking**: Rely on `lua_ls` (Lua Language Server) for type checking via EmmyLua annotations.

### Testing
We use `plenary.busted` for unit testing. The test suite is located in the `tests/` directory and utilizes a `minimal_init.lua` to securely set up Neovim's runtime path.

- **Running all tests**:
  ```bash
  nvim --headless -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"
  ```
- **Running a single test file**:
  ```bash
  nvim --headless -c "PlenaryBustedFile path/to/your_test_spec.lua { minimal_init = 'tests/minimal_init.lua' }"
  ```
- **Writing Tests**: Name test files with the suffix `_spec.lua`. When testing UI or asynchronous shell commands, use `vim.wait()` where appropriate. Prefer mocking `vim.system` (or internal execution functions like `require('fossil.api').exec`) rather than executing real `fossil` commands unless building integration tests.

## 2. Code Style Guidelines

### File Structure & Architecture
The project strictly separates commands, UI execution, and APIs to avoid monolithic files.
- `plugin/fossil.lua`: Neovim user commands (`:Fossil`), mappings, and initial logic.
- `lua/fossil/api.lua`: Core interface bridging Lua to the `fossil` shell binary.
- `lua/fossil/command.lua`: Command dispatcher. It processes user command arguments and delegates out to UI or file operations.
- `lua/fossil/util.lua`: Shared utility functions (e.g., path resolving).
- `lua/fossil/ui/`: Contains focused UI logic separated by feature:
  - `status.lua`: The interactive repository status window.
  - `window.lua`: Scratch buffers, quickfix lists, and basic split utilities.
  - `commit.lua`: The `acwrite` commit message buffer.
  - `blame.lua`: The interactive file blame and annotation window.

### Module Pattern
Always use the standard Lua module pattern. Do not pollute the global namespace (`_G`).
```lua
local M = {}

function M.my_function()
  -- Implementation
end

return M
```

### Formatting and Indentation
- **Indentation**: strictly use 2 spaces or tabs for indentation (allow `stylua` to auto-format).
- **Line Length**: Keep lines to a reasonable length, typically 100 characters max, to ensure readability in split windows.
- **Quotes**: Double quotes (`"`) are standard for strings in this codebase.

### Typing & Documentation
- **Annotations**: Always use EmmyLua/LuaLS annotations for all public/exported functions.
```lua
--- Executes a Fossil command and returns the output
--- @param args table A list of string arguments (e.g., {"status"})
--- @param cwd string|nil Optional working directory for the command
--- @return table lines List of lines from stdout/stderr
--- @return number code Exit code of the process
function M.exec(args, cwd)
```

### Naming Conventions
- **Variables & Functions**: Use `snake_case` for all variable, function, and file names (e.g., `resolve_target_path`, `commit_window`).
- **Constants**: Use `UPPER_SNAKE_CASE` for global constants.
- **Classes/Metatables**: If using pseudo-classes via Lua metatables, use `PascalCase` for the table name (e.g., `StatusBuffer`).

### Error Handling & External Commands
- **System Calls**: When invoking the `fossil` CLI, strictly use Neovim's `vim.system` API (requires Neovim 0.10+). Avoid using `io.popen` or `os.execute` or `vim.fn.system` as they block the Neovim UI thread.
- **Crash Prevention**: Wrap `vim.system` calls in a `pcall` (as seen in `api.lua`) to prevent hard crashes if the `fossil` binary is completely unavailable or throws Lua execution errors.
- **Failures**: Return sensible defaults (like an empty table and a `-1` exit code) rather than throwing hard errors with `error()`. Let the caller handle errors gracefully.
- **User Notifications**: Use `vim.notify` with appropriate log levels (`vim.log.levels.ERROR`, `vim.log.levels.WARN`, `vim.log.levels.INFO`) for user-facing errors rather than bare `print()` statements.

### Neovim API Usage
- **Prefer Lua APIs**: Use `vim.api.nvim_*` and `vim.fn.*` functions instead of `vim.cmd` whenever possible. However, `vim.cmd` is fine for simple window management like `vim.cmd('split')`.
- **Buffer Management**: Use scratch buffers (`buftype=nofile`, `bufhidden=wipe`, `noswapfile`) for temporary windows like the status view, diff views, and logs.

### Imports & Dependencies
- Use standard `require("fossil.module_name")` for internal modules. 
- Try to lazy-load modules or `require` them locally inside functions if they are only needed for specific commands.
- Avoid introducing external dependencies (like `plenary.nvim`) into the core production code unless absolutely necessary; keep the plugin dependency-free for standard users. Plenary is fine for tests.

### Fossil vs Git Terminology
- Remember that `fossil.nvim` targets Fossil SCM. Be careful not to mix up terminology when naming variables.
- Git has an "index" or "staging area"; Fossil does not have a formal staging area in the same way, but it tracks "added" or "edited" files. Emulate staging mechanics where requested (e.g., adding untracked files).
- Fossil uses a `.fslckout` file (or `_FOSSIL_` on Windows) at the root of a checkout instead of a `.git/` directory. Use this knowledge when looking for the repository root.