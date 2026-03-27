local api = require("fossil.api")

local M = {}

--- Gets the root directory of the current fossil repository
--- @return string|nil
function M.get_repo_root()
	local output, code = api.exec({ "info" })
	if code ~= 0 then
		return nil
	end
	for _, line in ipairs(output) do
		local root = line:match("^local%-root:%s*(.+)$")
		if root then
			root = vim.trim(root)
			-- Fossil returns paths with a trailing slash. Remove it for consistency.
			root = root:gsub("/+$", "")
			return root
		end
	end
	return nil
end

--- Resolves a relative path to an absolute path within the fossil repository
--- @param arg string|nil
--- @return string|nil
function M.resolve_target_path(arg)
	if not arg or arg == "" then
		return nil
	end
	if arg:sub(1, 1) == "/" then
		return arg
	end
	local root = M.get_repo_root()
	if root then
		return root .. "/" .. arg
	end
	return arg
end

--- Gets the path of the current buffer relative to the fossil repository root
--- @param buf number|nil Optional buffer number, defaults to 0
--- @return string
function M.get_relative_path(buf)
	local path = vim.api.nvim_buf_get_name(buf or 0)
	if not path or path == "" then
		return ""
	end
	
	-- Check if it's a fossil:// URL
	local fossil_uri = path:match("^fossil://(.+)$")
	if fossil_uri then
		path = fossil_uri
	end

	local root = M.get_repo_root()
	if root and path:sub(1, #root) == root then
		return path:sub(#root + 2) -- remove root and trailing slash
	end
	return vim.fn.fnamemodify(path, ":t")
end

return M
