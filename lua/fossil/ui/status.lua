local api = require("fossil.api")

local M = {}

--- Parse fossil status and extras into a structured format
--- @return table lines The lines representing the fossil status
local function get_status_lines()
	local status_out, code = api.exec({ "status" })
	if code ~= 0 then
		return { "Not in a fossil repository." }
	end

	local lines = {}

	-- Extract header info
	for _, line in ipairs(status_out) do
		if line:match("^[A-Z]+") then
			break -- Start of file changes
		end
		table.insert(lines, line)
	end
	table.insert(lines, "")

	-- Extract changes
	local changes = {}
	for _, line in ipairs(status_out) do
		if line:match("^[A-Z]+") then
			table.insert(changes, line)
		end
	end

	if #changes > 0 then
		table.insert(lines, "Changes:")
		for _, change in ipairs(changes) do
			table.insert(lines, "  " .. change)
		end
		table.insert(lines, "")
	end

	-- Extract untracked files (extras)
	local extras_out = api.exec({ "extras" })
	if #extras_out > 0 then
		table.insert(lines, "Untracked:")
		for _, file in ipairs(extras_out) do
			table.insert(lines, "  ? " .. file)
		end
	end

	return lines
end

--- Run an action on the file under cursor
--- @param filename string The file to open
--- @param mode string The mode to open it with (e.g. "split", "vsplit", "tab", "pedit", "edit")
local function open_file(filename, mode)
	local escaped = vim.fn.fnameescape(filename)
	vim.cmd("wincmd p")
	if mode == "split" then
		vim.cmd("split " .. escaped)
	elseif mode == "vsplit" then
		vim.cmd("vsplit " .. escaped)
	elseif mode == "tab" then
		vim.cmd("tabedit " .. escaped)
	elseif mode == "pedit" then
		vim.cmd("pedit " .. escaped)
	else
		vim.cmd("edit " .. escaped)
	end
end

local INLINE_PREFIX = "  | "

local function is_inline_diff_line(line)
	return line:sub(1, #INLINE_PREFIX) == INLINE_PREFIX
end

local function is_file_line(line)
	if is_inline_diff_line(line) then
		return false
	end
	if line:match("^%s+([A-Z]+)%s+(.+)$") then
		return true
	end
	if line:match("^%s+%?%s+(.+)$") then
		return true
	end
	return false
end

--- Jump to next or previous file in the status buffer
--- @param direction number 1 for next, -1 for previous
local function jump_to_file(direction)
	local line_nr = vim.api.nvim_win_get_cursor(0)[1]
	local total_lines = vim.api.nvim_buf_line_count(M.buf)

	local current = line_nr + direction
	while current > 0 and current <= total_lines do
		local line = vim.api.nvim_buf_get_lines(M.buf, current - 1, current, false)[1]
		if line and is_file_line(line) then
			vim.api.nvim_win_set_cursor(0, { current, 0 })
			return
		end
		current = current + direction
	end
end

--- Get the filename under the cursor in the status window
--- @return string|nil filename The filename under the cursor
--- @return string|nil state The state of the file (e.g. "ADDED", "EDITED", "UNTRACKED")
--- @return number|nil line_nr The line number where the file entry starts
local function get_file_under_cursor()
	local line_nr = vim.api.nvim_win_get_cursor(0)[1]
	local line = vim.api.nvim_get_current_line()

	if is_inline_diff_line(line) then
		while line_nr > 1 do
			line_nr = line_nr - 1
			line = vim.api.nvim_buf_get_lines(M.buf, line_nr - 1, line_nr, false)[1]
			if not is_inline_diff_line(line) then
				break
			end
		end
	end

	-- Match "  ADDED      filename" or "  EDITED     filename"
	local state, filename = line:match("^%s+([A-Z]+)%s+(.+)$")
	if state and filename then
		return filename, state, line_nr
	end

	-- Match "  ? filename"
	local untracked_file = line:match("^%s+%?%s+(.+)$")
	if untracked_file then
		return untracked_file, "UNTRACKED", line_nr
	end

	return nil, nil, nil
end

--- Remove inline diff for a file
--- @param line_nr number The starting line number of the file entry
local function inline_diff_remove(line_nr)
	local total = vim.api.nvim_buf_line_count(M.buf)
	local start = line_nr
	local stop = start
	while stop < total do
		local line = vim.api.nvim_buf_get_lines(M.buf, stop, stop + 1, false)[1]
		if not line or not is_inline_diff_line(line) then
			break
		end
		stop = stop + 1
	end

	if stop > start then
		vim.api.nvim_set_option_value("modifiable", true, { buf = M.buf })
		vim.api.nvim_buf_set_lines(M.buf, start, stop, false, {})
		vim.api.nvim_set_option_value("modifiable", false, { buf = M.buf })
	end
end

--- Insert inline diff for a file
--- @param line_nr number The line number where the file is listed
--- @param filename string The file to diff
--- @param state string The state of the file
local function inline_diff_insert(line_nr, filename, state)
	if state == "UNTRACKED" then
		vim.notify("Cannot diff untracked file.", vim.log.levels.WARN)
		return
	end

	local diff_lines = api.exec({ "diff", "--unified", filename })
	if #diff_lines == 0 then
		vim.notify("No diff for file.", vim.log.levels.INFO)
		return
	end

	local lines = {}
	for _, line in ipairs(diff_lines) do
		table.insert(lines, INLINE_PREFIX .. line)
	end

	vim.api.nvim_set_option_value("modifiable", true, { buf = M.buf })
	vim.api.nvim_buf_set_lines(M.buf, line_nr, line_nr, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = M.buf })
end

--- Toggle inline diff for a file
--- @param line_nr number The line number of the file entry
--- @param filename string The file to diff
--- @param state string The state of the file
local function inline_diff_toggle(line_nr, filename, state)
	local next_line = vim.api.nvim_buf_get_lines(M.buf, line_nr, line_nr + 1, false)[1]
	if next_line and is_inline_diff_line(next_line) then
		inline_diff_remove(line_nr)
	else
		inline_diff_insert(line_nr, filename, state)
	end
end

--- Perform an action on the file under the cursor
--- @param action_type string The action to perform
local function file_action(action_type)
	local filename, state, file_line = get_file_under_cursor()
	if not filename then
		return
	end

	if action_type == "diff" then
		if state == "UNTRACKED" then
			vim.notify("Cannot diff untracked file.", vim.log.levels.WARN)
		else
			require("fossil.command").execute({ "diff", filename })
		end
	elseif action_type == "diffsplit" then
		require("fossil.command").execute({ "diffsplit", filename })
	elseif action_type == "vdiffsplit" then
		require("fossil.command").execute({ "vdiffsplit", filename })
	elseif action_type == "hdiffsplit" then
		require("fossil.command").execute({ "hdiffsplit", filename })
	elseif action_type == "inline_toggle" then
		inline_diff_toggle(file_line, filename, state)
	elseif action_type == "inline_add" then
		inline_diff_insert(file_line, filename, state)
	elseif action_type == "inline_remove" then
		inline_diff_remove(file_line)
	elseif action_type == "stage" then
		if state == "UNTRACKED" then
			api.exec({ "add", filename })
			M.refresh()
		elseif state == "ADDED" then
			vim.notify("Already added.", vim.log.levels.INFO)
		else
			vim.notify("Fossil has no staging for tracked files.", vim.log.levels.INFO)
		end
	elseif action_type == "unstage" then
		if state == "ADDED" then
			api.exec({ "rm", "--soft", filename })
			M.refresh()
		elseif state == "UNTRACKED" then
			vim.notify("File is untracked.", vim.log.levels.INFO)
		else
			vim.notify("Nothing to unstage. Use X to discard changes.", vim.log.levels.INFO)
		end
	elseif action_type == "toggle" then
		if state == "UNTRACKED" then
			api.exec({ "add", filename })
			M.refresh()
		elseif state == "ADDED" then
			api.exec({ "rm", "--soft", filename })
			M.refresh()
		else
			vim.notify("Fossil has no staging for tracked files.", vim.log.levels.INFO)
		end
	elseif action_type == "discard" then
		if state == "UNTRACKED" then
			api.exec({ "clean", "--force", filename })
			M.refresh()
		elseif state == "ADDED" then
			api.exec({ "rm", filename })
			M.refresh()
		else
			api.exec({ "revert", filename })
			M.refresh()
		end
	elseif action_type == "open" then
		open_file(filename, "edit")
	elseif action_type == "split" then
		open_file(filename, "split")
	elseif action_type == "vsplit" then
		open_file(filename, "vsplit")
	elseif action_type == "tab" then
		open_file(filename, "tab")
	elseif action_type == "pedit" then
		open_file(filename, "pedit")
	end
end

local function open_help()
	local lines = {
		"==================================================================",
		"|                    Fossil Status Keybindings                   |",
		"==================================================================",
		"",
		" [ File Navigation ]",
		"   <CR>  Open file under cursor in current window",
		"   o     Open file in a new horizontal split",
		"   gO    Open file in a new vertical split",
		"   O     Open file in a new tab",
		"   p     Open file in preview window",
		"   )     Jump to the next file",
		"   (     Jump to the previous file",
		"",
		" [ Staging & Discarding ]",
		"   s     Stage (add) an untracked file",
		"   u     Unstage (untrack) an added file",
		"   -     Toggle stage/unstage status of a file",
		"   X     Discard changes (revert modified or clean untracked)",
		"",
		" [ Diffing & Review ]",
		"   dd    Open diff in a split (internal default)",
		"   dv    Open diff in a vertical split",
		"   ds    Open diff in a horizontal split",
		"   dh    Open diff in a horizontal split",
		"   dp    Show plain diff output in a scratch buffer",
		"   =     Toggle inline diff for the file under cursor",
		"   >     Expand inline diff for the file",
		"   <     Collapse inline diff for the file",
		"",
		" [ Repository Actions ]",
		"   cc    Open commit window to commit staged changes",
		"   ll    Open the repository timeline/log",
		"   czz   Push changes to the stash (fossil stash save)",
		"   R     Refresh the status window",
		"",
		" [ General ]",
		"   g?    Show this help message",
		"   gq    Close the status window",
		"   q     Close the status window / Close this help window",
		"",
		"==================================================================",
	}

	vim.cmd("botright new")
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_name(buf, "Fossil Help")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	vim.api.nvim_set_option_value("filetype", "fossilhelp", { buf = buf })

	-- Add basic syntax highlighting for the help menu
	local syntax_cmds = [[
		if exists("b:current_syntax")
		  finish
		endif

		syn match fossilHelpHeader "^ \[ .* \]$"
		syn match fossilHelpKey "^\s\+\S\+\s"
		syn match fossilHelpBorder "^====.*"
		syn match fossilHelpTitle "^|.*|$"

		hi def link fossilHelpHeader Title
		hi def link fossilHelpKey Special
		hi def link fossilHelpBorder Comment
		hi def link fossilHelpTitle String

		let b:current_syntax = "fossilhelp"
	]]
	vim.cmd(syntax_cmds)

	vim.keymap.set("n", "q", "<cmd>q<cr>", { buffer = buf, silent = true, noremap = true })
end

--- Refresh the status buffer
function M.refresh()
	if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
		return
	end
	local lines = get_status_lines()
	vim.api.nvim_set_option_value("modifiable", true, { buf = M.buf })
	vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = M.buf })
end

--- Open the status window
function M.open_status_window()
	-- Check if already open
	if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
		local win = vim.fn.bufwinnr(M.buf)
		if win ~= -1 then
			vim.cmd(win .. "wincmd w")
			M.refresh()
			return
		end
	end

	vim.cmd("botright new")
	M.buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_name(M.buf, "Fossil Status")

	M.refresh()

	-- Set buffer options
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = M.buf })
	vim.api.nvim_set_option_value("bufhidden", "hide", { buf = M.buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = M.buf })
	vim.api.nvim_set_option_value("filetype", "fossil", { buf = M.buf })

	local syntax_cmds = [[
		if exists("b:current_syntax")
		  finish
		endif

		syn match fossilDiffAdd    "^  | +.*"
		syn match fossilDiffRemove "^  | -.*"
		syn match fossilDiffHunk   "^  | @@.*"
		syn match fossilDiffHeader "^  | Index:.*"
		syn match fossilDiffHeader "^  | ===.*"
		syn match fossilDiffHeader "^  | ---.*"
		syn match fossilDiffHeader "^  | +++.*"

		hi def link fossilDiffAdd    Added
		hi def link fossilDiffRemove Removed
		hi def link fossilDiffHunk   Title
		hi def link fossilDiffHeader Type

		let b:current_syntax = "fossil-inline-diff"
	]]
	vim.cmd(syntax_cmds)

	-- Setup keymaps
	local opts = { buffer = M.buf, silent = true, noremap = true }

	-- Refresh
	vim.keymap.set("n", "R", function()
		M.refresh()
	end, opts)

	-- Open file
	vim.keymap.set("n", "<CR>", function()
		file_action("open")
	end, opts)
	vim.keymap.set("n", "o", function()
		file_action("split")
	end, opts)
	vim.keymap.set("n", "gO", function()
		file_action("vsplit")
	end, opts)
	vim.keymap.set("n", "O", function()
		file_action("tab")
	end, opts)
	vim.keymap.set("n", "p", function()
		file_action("pedit")
	end, opts)

	-- Diff
	vim.keymap.set("n", "dd", function()
		file_action("diffsplit")
	end, opts)
	vim.keymap.set("n", "dv", function()
		file_action("vdiffsplit")
	end, opts)
	vim.keymap.set("n", "ds", function()
		file_action("hdiffsplit")
	end, opts)
	vim.keymap.set("n", "dh", function()
		file_action("hdiffsplit")
	end, opts)
	vim.keymap.set("n", "dp", function()
		file_action("diff")
	end, opts)
	vim.keymap.set("n", "=", function()
		file_action("inline_toggle")
	end, opts)
	vim.keymap.set("n", ">", function()
		file_action("inline_add")
	end, opts)
	vim.keymap.set("n", "<", function()
		file_action("inline_remove")
	end, opts)
	vim.keymap.set("n", ")", function()
		jump_to_file(1)
	end, opts)
	vim.keymap.set("n", "(", function()
		jump_to_file(-1)
	end, opts)

	-- Stage/unstage/toggle/discard
	vim.keymap.set("n", "s", function()
		file_action("stage")
	end, opts)
	vim.keymap.set("n", "u", function()
		file_action("unstage")
	end, opts)
	vim.keymap.set("n", "-", function()
		file_action("toggle")
	end, opts)
	vim.keymap.set("n", "X", function()
		file_action("discard")
	end, opts)

	-- Commit (cc) & Log (ll) & Stash (czz)
	vim.keymap.set("n", "cc", function()
		require("fossil.command").execute({ "commit" })
	end, opts)
	vim.keymap.set("n", "ll", function()
		require("fossil.command").execute({ "clog" })
	end, opts)
	vim.keymap.set("n", "czz", function()
		require("fossil.api").exec({ "stash", "save" })
		M.refresh()
		vim.notify("Stashed changes.", vim.log.levels.INFO)
	end, opts)

	-- Help
	vim.keymap.set("n", "g?", function()
		open_help()
	end, opts)

	-- Quit
	vim.keymap.set("n", "q", "<cmd>q<cr>", opts)
	vim.keymap.set("n", "gq", "<cmd>q<cr>", opts)
end

return M
