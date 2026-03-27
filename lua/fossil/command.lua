local api = require("fossil.api")
local util = require("fossil.util")

local window = require("fossil.ui.window")
local blame = require("fossil.ui.blame")
local commit = require("fossil.ui.commit")

local M = {}

function M.show_help()
	local help_lines = {
		"fossil.nvim - A Fossil SCM integration for Neovim",
		"",
		"Usage: :Fossil <command> [args]",
		"",
		"COMMANDS",
		"  status",
		"    Open the status window, showing changes in the repository.",
		"",
		"  diff",
		"    Show the differences between the current working files and the last commit.",
		"",
		"  commit",
		"    Open a buffer to write a commit message and commit your changes.",
		"",
		"  blame, annotate",
		"    Show blame information for the current file.",
		"",
		"  diffsplit, vdiffsplit, hdiffsplit",
		"    Show the diff for the current file against the last committed version in a split.",
		"",
		"  info, show",
		"    Display information about the current repository or a specific object.",
		"",
		"  add, rm, delete, mv, move, rename",
		"    Perform file operations (add, remove, move).",
		"",
		"  checkout, co",
		"    Checkout a branch or tag.",
		"",
		"  tag",
		"    List, add, or delete tags.",
		"",
		"  pull, push, sync, fetch",
		"    Synchronize with a remote repository.",
		"",
		"  browse",
		"    Open the remote repository in a web browser.",
		"",
		"  help",
		"    Show this help message.",
		"",
	}
	window.open_scratch_buffer("Fossil Help", help_lines)
end

-- Command functions

local function status_command(args)
	require("fossil.ui.status").open_status_window()
end

local function diff_command(args)
	local output, code = api.exec(args)
	local buf = window.open_scratch_buffer("Fossil diff", output)
	vim.api.nvim_set_option_value("filetype", "diff", { buf = buf })
end

local function read_command(args)
	local filename = args[2] or vim.api.nvim_buf_get_name(0)
	if filename == "" then
		vim.notify("No file to read.", vim.log.levels.WARN)
		return
	end

	local buf = vim.api.nvim_get_current_buf()
	if vim.api.nvim_get_option_value("modified", { buf = buf }) then
		local force = false
		for _, arg in ipairs(args) do
			if arg == "!" then
				force = true
				break
			end
		end

		if not force then
			vim.notify(
				"Buffer is modified. Please save or discard changes, or use ! to force read.",
				vim.log.levels.ERROR
			)
			return
		end
	end

	local target = util.resolve_target_path(filename) or filename

	-- In fossil, "cat" without a revision gives the checked-out version.
	local output, code = api.exec({ "cat", target })
	if code ~= 0 then
		vim.notify("Fossil read failed.", vim.log.levels.ERROR)
		return
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, output)
	vim.api.nvim_set_option_value("modified", false, { buf = buf })
	vim.notify("Read " .. target .. " from fossil.", vim.log.levels.INFO)
end

local function write_command(args)
	local filename = args[2] or vim.api.nvim_buf_get_name(0)
	if filename == "" then
		vim.notify("No file to write.", vim.log.levels.WARN)
		return
	end
	local target = util.resolve_target_path(filename) or filename

	-- Fossil doesn't have a staging area like git's index, but write typically writes to disk and then adds.
	-- For Fossil, a Gwrite equivalent would write the current buffer to disk and run fossil add.
	vim.cmd("write")
	local _, code = api.exec({ "add", target })
	if code == 0 then
		vim.notify("Wrote and added " .. target .. " to fossil.", vim.log.levels.INFO)
	else
		vim.notify("Wrote file, but fossil add failed.", vim.log.levels.ERROR)
	end
end

local function edit_command(args)
	local filename = args[2] or vim.api.nvim_buf_get_name(0)
	if filename == "" then
		vim.notify("No file to edit.", vim.log.levels.WARN)
		return
	end
	local target = util.resolve_target_path(filename) or filename

	vim.cmd("edit " .. vim.fn.fnameescape(target))
end

local function browse_command(args)
	local output, code = api.exec({ "remote" })
	if code ~= 0 or #output == 0 or output[1] == "" then
		vim.notify("No remote found or fossil remote failed.", vim.log.levels.ERROR)
		return
	end

	-- Fossil URL format extraction (simple, assumes standard HTTP/HTTPS remotes)
	local remote = output[1]

	-- If there's a file, we could append /finfo?name=file or /artifact?name=...
	-- For GBrowse we just open the remote URL directly if we can't be more specific.
	if remote:match("^http") then
		local filename = args[2]
		local url = remote
		if filename and filename ~= "" then
			local target = util.resolve_target_path(filename) or filename
			-- convert absolute to relative for fossil URL
			local root = util.get_repo_root()
			if root and target:sub(1, #root) == root then
				target = target:sub(#root + 2) -- remove root and slash
			end
			url = url .. "/finfo?name=" .. target
		end
		vim.ui.open(url)
	else
		vim.notify("Remote is not a standard HTTP(S) URL: " .. remote, vim.log.levels.WARN)
	end
end

local function delete_command(args, keep_buffer)
	local filename = args[2] or vim.api.nvim_buf_get_name(0)
	if filename == "" then
		vim.notify("No file to delete.", vim.log.levels.WARN)
		return
	end
	local target = util.resolve_target_path(filename) or filename

	local out, code = api.exec({ "rm", "--hard", target })
	if code == 0 then
		vim.notify("Deleted " .. target, vim.log.levels.INFO)
		-- Remove buffer
		if not keep_buffer then
			local absolute_target = vim.fn.fnamemodify(target, ":p")
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_get_name(buf) == absolute_target then
					vim.cmd("bdelete! " .. buf)
					break
				end
			end
		end
		-- Refresh status if open
		local has_status, status_mod = pcall(require, "fossil.ui.status")
		if has_status and status_mod.refresh then
			status_mod.refresh()
		end
	else
		vim.notify("Failed to delete " .. target .. ":\n" .. table.concat(out, "\n"), vim.log.levels.ERROR)
	end
end

local function move_command(args)
	local filename = vim.api.nvim_buf_get_name(0)
	if filename == "" then
		vim.notify("No file to move.", vim.log.levels.WARN)
		return
	end
	local dest = args[2]
	if not dest or dest == "" then
		vim.notify("Destination required.", vim.log.levels.WARN)
		return
	end

	local target = util.resolve_target_path(filename) or filename
	local dest_target = util.resolve_target_path(dest) or dest

	local out, code = api.exec({ "mv", "--hard", target, dest_target })
	if code == 0 then
		vim.notify("Moved to " .. dest_target, vim.log.levels.INFO)
		vim.cmd("edit " .. vim.fn.fnameescape(dest_target))
		-- Remove old buffer
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_get_name(buf) == filename then
				vim.cmd("bdelete! " .. buf)
				break
			end
		end
		-- Refresh status if open
		local has_status, status_mod = pcall(require, "fossil.ui.status")
		if has_status and status_mod.refresh then
			status_mod.refresh()
		end
	else
		vim.notify("Failed to move:\n" .. table.concat(out, "\n"), vim.log.levels.ERROR)
	end
end

local function cd_command(args, lcd)
	local root = util.get_repo_root()
	if not root then
		vim.notify("Not in a fossil repository.", vim.log.levels.ERROR)
		return
	end
	if lcd then
		vim.cmd("lcd " .. vim.fn.fnameescape(root))
	else
		vim.cmd("cd " .. vim.fn.fnameescape(root))
	end
	vim.notify("Changed directory to " .. root, vim.log.levels.INFO)
end

local function checkout_command(args)
	if #args < 2 then
		vim.notify("Usage: Fossil checkout <branch/tag>", vim.log.levels.WARN)
		return
	end
	local target = args[2]
	vim.notify("Fossil checkout running...", vim.log.levels.INFO)
	api.exec_async({ "update", target }, nil, function(output, code)
		if code == 0 then
			vim.notify("Fossil checkout complete. Switched to " .. target, vim.log.levels.INFO)
		else
			vim.notify("Fossil checkout failed:\n" .. table.concat(output, "\n"), vim.log.levels.ERROR)
		end
		-- Attempt to refresh status if it's open
		local has_status, status_mod = pcall(require, "fossil.ui.status")
		if has_status and status_mod.refresh then
			status_mod.refresh()
		end
	end)
end

local function tag_command(args)
	if #args == 1 then
		-- list tags
		local output, code = api.exec({ "tag", "list" })
		if code == 0 then
			window.open_scratch_buffer("Fossil Tags", output)
		else
			vim.notify("Failed to list tags:\n" .. table.concat(output, "\n"), vim.log.levels.ERROR)
		end
	elseif #args >= 3 and args[2] == "add" then
		-- add tag
		local tag_name = args[3]
		local revision = args[4] or "tip"
		local out, code = api.exec({ "tag", "add", tag_name, revision })
		if code == 0 then
			vim.notify("Tag '" .. tag_name .. "' added to " .. revision, vim.log.levels.INFO)
		else
			vim.notify("Failed to add tag:\n" .. table.concat(out, "\n"), vim.log.levels.ERROR)
		end
	elseif #args >= 3 and args[2] == "delete" then
		-- delete tag
		local tag_name = args[3]
		local out, code = api.exec({ "tag", "delete", tag_name })
		if code == 0 then
			vim.notify("Tag '" .. tag_name .. "' deleted", vim.log.levels.INFO)
		else
			vim.notify("Failed to delete tag:\n" .. table.concat(out, "\n"), vim.log.levels.ERROR)
		end
	else
		vim.notify("Usage: Fossil tag [list|add <name> [revision]|delete <name>]", vim.log.levels.WARN)
	end
end

local function show_command(args)
	local output, code = api.exec(args)
	if #output == 0 then
		vim.api.nvim_echo({ { "Fossil command executed successfully (no output).", "Normal" } }, false, {})
	else
		window.open_scratch_buffer("Fossil " .. table.concat(args, " "), output)
	end
end

local function sync_command(args)
	vim.notify("Fossil " .. args[1] .. " running...", vim.log.levels.INFO)
	api.exec_async(args, nil, function(output, code)
		if code == 0 then
			vim.notify("Fossil " .. args[1] .. " complete.", vim.log.levels.INFO)
		else
			vim.notify("Fossil " .. args[1] .. " failed:\n" .. table.concat(output, "\n"), vim.log.levels.ERROR)
		end
		-- Attempt to refresh status if it's open
		local has_status, status_mod = pcall(require, "fossil.ui.status")
		if has_status and status_mod.refresh then
			status_mod.refresh()
		end
	end)
end

local function wq_command(args, force)
	local filename = args[2] or vim.api.nvim_buf_get_name(0)
	if filename == "" then
		vim.notify("No file to write.", vim.log.levels.WARN)
		return
	end
	local target = util.resolve_target_path(filename) or filename

	vim.cmd("write" .. (force and "!" or ""))
	local _, code = api.exec({ "add", target })
	if code == 0 then
		vim.notify("Wrote and added " .. target .. " to fossil.", vim.log.levels.INFO)
		vim.cmd("quit" .. (force and "!" or ""))
	else
		vim.notify("Wrote file, but fossil add failed.", vim.log.levels.ERROR)
	end
end

local function edit_with_cmd(args, vim_cmd)
	local filename = args[2] or vim.api.nvim_buf_get_name(0)
	if filename == "" then
		vim.notify("No file specified.", vim.log.levels.WARN)
		return
	end
	local target = util.resolve_target_path(filename) or filename
	vim.cmd(vim_cmd .. " " .. vim.fn.fnameescape(target))
end

-- Command dispatch table
local commands = {
	status = status_command,
	diff = diff_command,
	blame = blame.open_blame_view,
	annotate = blame.open_blame_view,
	diffsplit = function(args)
		window.open_diffsplit(args)
	end,
	vdiffsplit = function(args)
		window.open_diffsplit(args, "vsplit")
	end,
	hdiffsplit = function(args)
		window.open_diffsplit(args, "split", true)
	end,
	difftool = window.open_difftool,
	grep = window.open_quickfix_from_exec,
	clog = window.open_clog,
	read = read_command,
	write = write_command,
	edit = edit_command,
	browse = browse_command,
	commit = commit.open_commit_buffer,
	delete = function(args)
		delete_command(args, false)
	end,
	rm = function(args)
		delete_command(args, false)
	end,
	unlink = function(args)
		delete_command(args, true)
	end,
	move = move_command,
	mv = move_command,
	rename = move_command,
	cd = function(args)
		cd_command(args, false)
	end,
	lcd = function(args)
		cd_command(args, true)
	end,
	split = function(args)
		edit_with_cmd(args, "split")
	end,
	vsplit = function(args)
		edit_with_cmd(args, "vsplit")
	end,
	tabedit = function(args)
		edit_with_cmd(args, "tabedit")
	end,
	pedit = function(args)
		edit_with_cmd(args, "pedit")
	end,
	drop = function(args)
		edit_with_cmd(args, "drop")
	end,
	lgrep = function(args)
		window.open_quickfix_from_exec(args, nil, true)
	end,
	gllog = function(args)
		window.open_clog(args, true)
	end,
	wq = function(args)
		local force = false
		for _, arg in ipairs(args) do
			if arg == "!" then
				force = true
			end
		end
		wq_command(args, force)
	end,
	checkout = checkout_command,
	co = checkout_command,
	tag = tag_command,
	show = show_command,
	info = show_command,
	push = sync_command,
	pull = sync_command,
	sync = sync_command,
	fetch = sync_command,
	clone = sync_command,
	update = sync_command,
	help = M.show_help,
}

--- Run a fossil command and print its output in a scratch buffer or directly
--- @param args table
function M.execute(args)
	local is_bang = false
	local is_paginate = false
	local filtered_args = {}

	for _, arg in ipairs(args) do
		if arg == "!" then
			is_bang = true
		elseif arg == "-p" or arg == "--paginate" then
			is_paginate = true
		else
			table.insert(filtered_args, arg)
		end
	end
	args = filtered_args

	if #args == 0 then
		require("fossil.ui.status").open_status_window()
		return
	end

	local cmd = args[1]
	local command_func = commands[cmd]

	if command_func then
		command_func(args)
	else
		if is_bang then
			-- ! executes asynchronously and outputs to quickfix/preview
			local title = "Fossil " .. table.concat(args, " ")
			api.exec_async(args, nil, function(output, code)
				if #output == 0 then
					vim.notify("No output from " .. title, vim.log.levels.INFO)
				else
					-- dump to a scratch buffer in a small split, acting as a preview
					local buf = window.open_scratch_buffer(title, output)
					vim.cmd("pedit | wincmd P | buffer " .. buf .. " | wincmd p")
				end
			end)
		elseif is_paginate then
			-- -p / --paginate captures output to temp buffer and splits
			local output, code = api.exec(args)
			if #output == 0 then
				vim.notify("Fossil command executed successfully (no output).", vim.log.levels.INFO)
			else
				local title = "Fossil " .. table.concat(args, " ")
				local buf = window.open_scratch_buffer(title, output)
				vim.cmd("sbuffer " .. buf)
			end
		else
			-- Generic command: dump output to a scratch buffer
			local output, code = api.exec(args)
			if #output == 0 then
				vim.api.nvim_echo({ { "Fossil command executed successfully (no output).", "Normal" } }, false, {})
			else
				window.open_scratch_buffer("Fossil " .. table.concat(args, " "), output)
			end
		end
	end
end

return M
