local api = require("fossil.api")
local util = require("fossil.util")

local window = require("fossil.ui.window")
local blame = require("fossil.ui.blame")
local commit = require("fossil.ui.commit")
local ops = require("fossil.operations")

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

local function status_command(args)
	require("fossil.ui.status").open_status_window()
end

-- Command dispatch table
local commands = {
	status = status_command,
	diff = ops.diff,
	blame = blame.open_blame_view,
	annotate = blame.open_blame_view,
	diffsplit = function(args, is_bang)
		window.open_diffsplit(args, nil, false, is_bang)
	end,
	vdiffsplit = function(args, is_bang)
		window.open_diffsplit(args, "vsplit", false, is_bang)
	end,
	hdiffsplit = function(args, is_bang)
		window.open_diffsplit(args, "split", true, is_bang)
	end,
	difftool = function(args, is_bang)
		args[1] = "diff"
		window.open_difftool(args, is_bang)
	end,
	mergetool = function(args, is_bang)
		window.open_mergetool(args)
	end,
	grep = function(args)
		args[1] = "grep"
		window.open_quickfix_from_exec(args)
	end,
	lgrep = function(args)
		args[1] = "grep"
		window.open_quickfix_from_exec(args, nil, true)
	end,
	clog = function(args)
		if #args > 1 then
			args[1] = "timeline"
			window.open_clog(args, false)
		else
			require("fossil.ui.timeline").open_timeline_window()
		end
	end,
	timeline = function(args)
		if #args > 1 then
			window.open_clog(args, false)
		else
			require("fossil.ui.timeline").open_timeline_window()
		end
	end,
	finfo = require("fossil.ui.finfo").open_finfo_window,
	gllog = function(args)
		args[1] = "timeline"
		window.open_clog(args, true)
	end,
	read = ops.read,
	write = ops.write,
	edit = ops.edit,
	browse = ops.browse,
	commit = commit.open_commit_buffer,
	delete = function(args)
		ops.delete(args, false)
	end,
	rm = function(args)
		ops.delete(args, false)
	end,
	unlink = function(args)
		ops.delete(args, true)
	end,
	move = ops.move,
	mv = ops.move,
	rename = ops.move,
	cd = function(args)
		ops.cd(args, false)
	end,
	lcd = function(args)
		ops.cd(args, true)
	end,
	split = function(args)
		ops.edit_with_cmd(args, "split")
	end,
	vsplit = function(args)
		ops.edit_with_cmd(args, "vsplit")
	end,
	tabedit = function(args)
		ops.edit_with_cmd(args, "tabedit")
	end,
	pedit = function(args)
		ops.edit_with_cmd(args, "pedit")
	end,
	drop = function(args)
		ops.edit_with_cmd(args, "drop")
	end,
	wq = function(args)
		local force = false
		for _, arg in ipairs(args) do
			if arg == "!" then
				force = true
			end
		end
		ops.wq(args, force)
	end,
	checkout = ops.checkout,
	co = ops.checkout,
	branch = function(args)
		if #args > 1 then
			ops.show(args)
		else
			require("fossil.ui.branch").open_branch_window()
		end
	end,
	ticket = function(args)
		if #args > 1 then
			ops.show(args)
		else
			require("fossil.ui.ticket").open_ticket_window()
		end
	end,
	wiki = function(args)
		if #args > 1 then
			ops.show(args)
		else
			require("fossil.ui.wiki").open_wiki_window()
		end
	end,
	tag = ops.tag,
	show = ops.show,
	info = ops.show,
	undo = ops.undo,
	redo = ops.redo,
	push = ops.sync,
	pull = ops.sync,
	sync = ops.sync,
	fetch = ops.sync,
	clone = ops.sync,
	update = ops.sync,
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
		command_func(args, is_bang, is_paginate)
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
