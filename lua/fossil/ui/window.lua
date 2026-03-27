local api = require("fossil.api")
local util = require("fossil.util")

local M = {}

--- Opens a scratch buffer to show fossil command output
--- @param name string The name of the scratch buffer
--- @param lines table The lines to display in the buffer
--- @return number buf The buffer ID
function M.open_scratch_buffer(name, lines)
	vim.cmd("botright new")
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_name(buf, name .. " - " .. tostring(os.time()))
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- Set buffer options
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	-- Easy quit
	vim.keymap.set("n", "q", "<cmd>q<cr>", { buffer = buf, silent = true, noremap = true })

	return buf
end

--- Execute a fossil command and populate the quickfix list with the output
--- @param args table The command arguments
--- @param title string|nil The title for the quickfix list
--- @param use_loclist boolean|nil Whether to use the location list instead
function M.open_quickfix_from_exec(args, title, use_loclist)
	local output, code = api.exec(args)
	if #output == 0 then
		vim.notify("No output.", vim.log.levels.INFO)
		return
	end

	local items = {}
	for _, line in ipairs(output) do
		local filename, lnum, text = line:match("^([^:]+):(%d+):%s*(.*)$")
		if filename and lnum then
			table.insert(items, { filename = filename, lnum = tonumber(lnum), text = text })
		else
			local file_only, text_only = line:match("^([^:]+):%s*(.*)$")
			if file_only then
				table.insert(items, { filename = file_only, lnum = 1, text = text_only })
			else
				table.insert(items, { filename = "", lnum = 1, text = line })
			end
		end
	end

	local list_title = title or ("Fossil " .. table.concat(args, " "))
	if use_loclist then
		vim.fn.setloclist(0, {}, " ", { title = list_title, items = items })
		vim.cmd("lopen")
	else
		vim.fn.setqflist({}, " ", { title = list_title, items = items })
		vim.cmd("copen")
	end
end

--- Open the fossil timeline/log in a quickfix list
--- @param args table The command arguments
--- @param use_loclist boolean|nil Whether to use the location list instead
function M.open_clog(args, use_loclist)
	local output, code = api.exec(args)
	if #output == 0 then
		vim.notify("No output.", vim.log.levels.INFO)
		return
	end

	local items = {}
	for _, line in ipairs(output) do
		local hash, comment = line:match("^([0-9a-f]+)%s+(.+)$")
		if hash then
			table.insert(items, { filename = "", lnum = 1, text = hash .. " " .. comment })
		else
			table.insert(items, { filename = "", lnum = 1, text = line })
		end
	end

	if use_loclist then
		vim.fn.setloclist(0, {}, " ", { title = "Fossil log", items = items })
		vim.cmd("lopen")
	else
		vim.fn.setqflist({}, " ", { title = "Fossil log", items = items })
		vim.cmd("copen")
	end
end

--- Open a diff split against the last committed version
--- @param args table The command arguments
--- @param split_cmd string|nil The split command to use (e.g. "vsplit")
--- @param novertical boolean|nil If true, use horizontal split
--- @param is_bang boolean|nil If true, retain focus on original window
function M.open_diffsplit(args, split_cmd, novertical, is_bang)
	local filename = args[2] or vim.api.nvim_buf_get_name(0)
	if filename == "" then
		vim.notify("diffsplit requires a file path.", vim.log.levels.WARN)
		return
	end

	local target = util.resolve_target_path(filename)
	if not target or target == "" then
		vim.notify("Could not resolve file path.", vim.log.levels.ERROR)
		return
	end

	-- Run fossil cat to get the original file contents
	local output, code = api.exec({ "cat", target })
	if code ~= 0 then
		vim.notify("Could not retrieve original file contents.", vim.log.levels.ERROR)
		return
	end

	-- Make sure we are in the buffer we want to diff
	if vim.api.nvim_buf_get_name(0) ~= target then
		vim.cmd("edit " .. vim.fn.fnameescape(target))
	end

	-- Enable diff mode on current window
	if novertical then
		vim.api.nvim_set_option_value("diffopt", "filler,internal", { scope = "global" })
	end
	vim.cmd("diffthis")

	-- Open split for the historical version
	local split = split_cmd or "split"
	if split == "vsplit" then
		vim.cmd("leftabove vnew")
	else
		vim.cmd("leftabove new")
	end

	-- Set up the scratch buffer for historical version
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_name(buf, "fossil://" .. target)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, output)

	-- Match filetype from original
	local original_ft = vim.filetype.match({ filename = target })
	if original_ft then
		vim.api.nvim_set_option_value("filetype", original_ft, { buf = buf })
	end

	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	-- Enable diff mode on this new window
	vim.cmd("diffthis")

	-- Retain focus on original window if ! was used
	if is_bang then
		vim.cmd("wincmd p")
	end
end

function M.open_difftool(args, is_bang)
	local is_y = false
	local filtered_args = {}
	for _, arg in ipairs(args) do
		if arg == "-y" then
			is_y = true
		else
			table.insert(filtered_args, arg)
		end
	end

	local output, code = api.exec(filtered_args)
	if #output == 0 then
		vim.notify("No diff output.", vim.log.levels.INFO)
		return
	end

	local items = {}
	for _, line in ipairs(output) do
		local status, filename = line:match("^([A-Z]+)%s+(.+)$")
		if filename then
			table.insert(items, { filename = filename, lnum = 1, text = status })
		else
			local alt = line:match("^([^%s]+)$")
			if alt then
				table.insert(items, { filename = alt, lnum = 1, text = "diff" })
			end
		end
	end

	if #items > 0 then
		if is_y then
			-- Open each changed file in a new tab, and invoke Gdiffsplit!
			for _, item in ipairs(items) do
				local file = item.filename
				vim.cmd("tabedit " .. vim.fn.fnameescape(file))
				M.open_diffsplit({ "diffsplit", file }, "vsplit", false, true)
			end
			vim.cmd("tabfirst")
		else
			vim.fn.setqflist({}, " ", { title = "Fossil diff", items = items })
			vim.cmd("copen")
			if not is_bang then
				vim.cmd("cfirst")
			end
		end
	end
end

function M.open_mergetool(args)
	-- Fossil marks conflicts with <<<<<<< in files. We can find these with grep.
	local grep_args = { "grep", "<<<<<<<" }
	M.open_quickfix_from_exec(grep_args, "Fossil merge conflicts")
end

return M
