local M = {}

--- Run a fossil command synchronously and return its output as a table of lines
--- @param args table: The arguments to pass to fossil (e.g. {"status"})
--- @param cwd string|nil: Optional working directory
--- @return table: List of lines from stdout/stderr
--- @return number: Exit code
function M.exec(args, cwd)
	local cmd = { "fossil" }
	for _, arg in ipairs(args) do
		table.insert(cmd, arg)
	end

	local ok, obj = pcall(function()
		return vim.system(cmd, { text = true, cwd = cwd }):wait()
	end)

	if not ok or not obj then
		return { "Failed to execute fossil command: " .. tostring(obj) }, -1
	end

	local output = {}
	if obj.stdout then
		local lines = vim.split(obj.stdout, "\r?\n")
		if #lines > 0 and lines[#lines] == "" then
			table.remove(lines)
		end
		for _, line in ipairs(lines) do
			table.insert(output, line)
		end
	end
	if obj.stderr then
		local lines = vim.split(obj.stderr, "\r?\n")
		if #lines > 0 and lines[#lines] == "" then
			table.remove(lines)
		end
		for _, line in ipairs(lines) do
			table.insert(output, line)
		end
	end

	return output, obj.code
end

--- Run a fossil command asynchronously
--- @param args table: The arguments to pass to fossil
--- @param cwd string|nil: Optional working directory
--- @param callback function: Called on completion with (output_lines, exit_code)
function M.exec_async(args, cwd, callback)
	local cmd = { "fossil" }
	for _, arg in ipairs(args) do
		table.insert(cmd, arg)
	end

	local ok, err = pcall(function()
		vim.system(cmd, { text = true, cwd = cwd }, function(obj)
			local output = {}
			if obj.stdout then
				local lines = vim.split(obj.stdout, "\r?\n")
				if #lines > 0 and lines[#lines] == "" then
					table.remove(lines)
				end
				for _, line in ipairs(lines) do
					table.insert(output, line)
				end
			end
			if obj.stderr then
				local lines = vim.split(obj.stderr, "\r?\n")
				if #lines > 0 and lines[#lines] == "" then
					table.remove(lines)
				end
				for _, line in ipairs(lines) do
					table.insert(output, line)
				end
			end
			if callback then
				vim.schedule(function()
					callback(output, obj.code)
				end)
			end
		end)
	end)

	if not ok and callback then
		vim.schedule(function()
			callback({ "Failed to execute fossil command: " .. tostring(err) }, -1)
		end)
	end
end

--- Check if the current directory or the given directory is inside a fossil checkout
--- @param dir string|nil
--- @return boolean
function M.is_checkout(dir)
	local _, code = M.exec({ "info" }, dir)
	return code == 0
end

return M
