local api = require("fossil.api")
local window = require("fossil.ui.window")
local util = require("fossil.util")

local M = {}

--- Format: `2026-03-27 [e829a478ac] mod test (user: fw, artifact: [b314e28493], branch: trunk)`
local function get_hash_under_cursor()
	local line = vim.api.nvim_get_current_line()
	local hash = line:match("%[([0-9a-fA-F]+)%]")
	return hash
end

function M.open_finfo_window(args)
	local filename = args[2] or vim.api.nvim_buf_get_name(0)
	if filename == "" then
		vim.notify("No file specified for finfo.", vim.log.levels.WARN)
		return
	end

	local target = util.resolve_target_path(filename) or filename

	local output, code = api.exec({ "finfo", target })
	if code ~= 0 then
		vim.notify("Failed to get finfo for " .. target, vim.log.levels.ERROR)
		return
	end

	vim.cmd("botright new")
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_name(buf, "Fossil Finfo: " .. vim.fn.fnamemodify(target, ":t") .. " - " .. tostring(os.time()))

	local lines = {
		"==================================================================",
		"|                        Fossil File History                     |",
		"==================================================================",
		" <CR>  View file at this commit",
		" d     Diff this commit against working copy",
		" D     Diff this commit against the commit below it",
		" m     Mark/Unmark commit for two-way diff",
		" M     Diff marked commit against commit under cursor",
		" q     Close this window",
		"==================================================================",
		"File: " .. target,
		"",
	}

	for _, line in ipairs(output) do
		table.insert(lines, line)
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- Set buffer options
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	vim.api.nvim_set_option_value("filetype", "fossilfinfo", { buf = buf })

	-- Store local state
	vim.api.nvim_buf_set_var(buf, "fossil_finfo_target", target)
	vim.api.nvim_buf_set_var(buf, "fossil_finfo_marked", "")

	-- Basic syntax highlighting
	local syntax_cmds = [[
		if exists("b:current_syntax")
		  finish
		endif

		syn match fossilFinfoHeader "^====.*"
		syn match fossilFinfoTitle "^|.*|$"
		syn match fossilFinfoKey "^\s\+\S\+\s"
		syn match fossilFinfoHash "\[\x\+\]"
		syn match fossilFinfoDate "^\d\{4}-\d\{2}-\d\{2}"

		hi def link fossilFinfoHeader Comment
		hi def link fossilFinfoTitle Type
		hi def link fossilFinfoKey Special
		hi def link fossilFinfoHash Identifier
		hi def link fossilFinfoDate String

		let b:current_syntax = "fossilfinfo"
	]]
	vim.cmd(syntax_cmds)

	local opts = { buffer = buf, silent = true, noremap = true }

	vim.keymap.set("n", "<CR>", function()
		local hash = get_hash_under_cursor()
		if not hash then
			return
		end
		local tgt = vim.api.nvim_buf_get_var(buf, "fossil_finfo_target")
		local out, c = api.exec({ "cat", tgt, "-r", hash })
		if c == 0 then
			local b = window.open_scratch_buffer("fossil://" .. hash .. "/" .. vim.fn.fnamemodify(tgt, ":t"), out)
			local ft = vim.filetype.match({ filename = tgt })
			if ft then
				vim.api.nvim_set_option_value("filetype", ft, { buf = b })
			end
		else
			vim.notify("Failed to get file contents.", vim.log.levels.ERROR)
		end
	end, opts)

	vim.keymap.set("n", "d", function()
		local hash = get_hash_under_cursor()
		if not hash then
			return
		end
		local tgt = vim.api.nvim_buf_get_var(buf, "fossil_finfo_target")

		-- Use existing diffsplit logic against specific version by overriding args?
		-- We can just open working copy, diffthis, and open scratch for version
		vim.cmd("wincmd p")
		local current_buf = vim.api.nvim_get_current_buf()
		local is_modified = vim.api.nvim_get_option_value("modified", { buf = current_buf })
		if vim.api.nvim_buf_get_name(current_buf) ~= tgt then
			if is_modified then
				vim.cmd("split " .. vim.fn.fnameescape(tgt))
			else
				local ok = pcall(function()
					vim.cmd("edit " .. vim.fn.fnameescape(tgt))
				end)
				if not ok then
					vim.cmd("split " .. vim.fn.fnameescape(tgt))
				end
			end
		end
		vim.cmd("diffthis")

		local out, c = api.exec({ "cat", tgt, "-r", hash })
		if c == 0 then
			vim.cmd("vsplit")
			local b = vim.api.nvim_get_current_buf()
			vim.api.nvim_buf_set_name(
				b,
				"fossil://" .. hash .. "/" .. vim.fn.fnamemodify(tgt, ":t") .. " - " .. tostring(os.time())
			)
			vim.api.nvim_buf_set_lines(b, 0, -1, false, out)
			local ft = vim.filetype.match({ filename = tgt })
			if ft then
				vim.api.nvim_set_option_value("filetype", ft, { buf = b })
			end
			vim.api.nvim_set_option_value("buftype", "nofile", { buf = b })
			vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = b })
			vim.api.nvim_set_option_value("swapfile", false, { buf = b })
			vim.api.nvim_set_option_value("modifiable", false, { buf = b })
			vim.cmd("diffthis")
		else
			vim.cmd("diffoff")
			vim.notify("Failed to get file contents.", vim.log.levels.ERROR)
		end
	end, opts)

	vim.keymap.set("n", "D", function()
		local hash = get_hash_under_cursor()
		if not hash then
			return
		end
		local tgt = vim.api.nvim_buf_get_var(buf, "fossil_finfo_target")

		-- find next commit hash below
		local row = vim.api.nvim_win_get_cursor(0)[1]
		local total = vim.api.nvim_buf_line_count(buf)
		local prev_hash = nil
		for i = row, total - 1 do
			local l = vim.api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
			prev_hash = l:match("%[([0-9a-fA-F]+)%]")
			if prev_hash and prev_hash ~= hash then
				break
			end
		end

		if not prev_hash then
			vim.notify("No older commit found.", vim.log.levels.WARN)
			return
		end

		-- diff hash against prev_hash
		local out1, c1 = api.exec({ "cat", tgt, "-r", hash })
		local out2, c2 = api.exec({ "cat", tgt, "-r", prev_hash })

		if c1 == 0 and c2 == 0 then
			vim.cmd("tabnew")
			local b2 = vim.api.nvim_get_current_buf()
			vim.api.nvim_buf_set_name(
				b2,
				"fossil://" .. prev_hash .. "/" .. vim.fn.fnamemodify(tgt, ":t") .. " - " .. tostring(os.time())
			)
			vim.api.nvim_buf_set_lines(b2, 0, -1, false, out2)
			local ft = vim.filetype.match({ filename = tgt })
			if ft then
				vim.api.nvim_set_option_value("filetype", ft, { buf = b2 })
			end
			vim.api.nvim_set_option_value("buftype", "nofile", { buf = b2 })
			vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = b2 })
			vim.api.nvim_set_option_value("swapfile", false, { buf = b2 })
			vim.api.nvim_set_option_value("modifiable", false, { buf = b2 })
			vim.cmd("diffthis")

			vim.cmd("rightbelow vsplit")
			local b1 = vim.api.nvim_get_current_buf()
			vim.api.nvim_buf_set_name(
				b1,
				"fossil://" .. hash .. "/" .. vim.fn.fnamemodify(tgt, ":t") .. " - " .. tostring(os.time())
			)
			vim.api.nvim_buf_set_lines(b1, 0, -1, false, out1)
			if ft then
				vim.api.nvim_set_option_value("filetype", ft, { buf = b1 })
			end
			vim.api.nvim_set_option_value("buftype", "nofile", { buf = b1 })
			vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = b1 })
			vim.api.nvim_set_option_value("swapfile", false, { buf = b1 })
			vim.api.nvim_set_option_value("modifiable", false, { buf = b1 })
			vim.cmd("diffthis")
		else
			vim.notify("Failed to get file contents for diff.", vim.log.levels.ERROR)
		end
	end, opts)

	vim.keymap.set("n", "m", function()
		local hash = get_hash_under_cursor()
		if not hash then
			return
		end
		local current_marked = vim.api.nvim_buf_get_var(buf, "fossil_finfo_marked")
		if current_marked == hash then
			vim.api.nvim_buf_set_var(buf, "fossil_finfo_marked", "")
			vim.notify("Unmarked commit " .. hash, vim.log.levels.INFO)
		else
			vim.api.nvim_buf_set_var(buf, "fossil_finfo_marked", hash)
			vim.notify("Marked commit " .. hash .. " for diffing", vim.log.levels.INFO)
		end
	end, opts)

	vim.keymap.set("n", "M", function()
		local hash = get_hash_under_cursor()
		if not hash then
			return
		end
		local marked = vim.api.nvim_buf_get_var(buf, "fossil_finfo_marked")
		if not marked or marked == "" then
			vim.notify("No commit marked. Use 'm' to mark a commit.", vim.log.levels.WARN)
			return
		end
		if marked == hash then
			vim.notify("Cannot diff a commit against itself.", vim.log.levels.WARN)
			return
		end

		local tgt = vim.api.nvim_buf_get_var(buf, "fossil_finfo_target")
		local out1, c1 = api.exec({ "cat", tgt, "-r", hash })
		local out2, c2 = api.exec({ "cat", tgt, "-r", marked })

		if c1 == 0 and c2 == 0 then
			vim.cmd("tabnew")
			local b2 = vim.api.nvim_get_current_buf()
			vim.api.nvim_buf_set_name(
				b2,
				"fossil://" .. marked .. "/" .. vim.fn.fnamemodify(tgt, ":t") .. " - " .. tostring(os.time())
			)
			vim.api.nvim_buf_set_lines(b2, 0, -1, false, out2)
			local ft = vim.filetype.match({ filename = tgt })
			if ft then
				vim.api.nvim_set_option_value("filetype", ft, { buf = b2 })
			end
			vim.api.nvim_set_option_value("buftype", "nofile", { buf = b2 })
			vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = b2 })
			vim.api.nvim_set_option_value("swapfile", false, { buf = b2 })
			vim.api.nvim_set_option_value("modifiable", false, { buf = b2 })
			vim.cmd("diffthis")

			vim.cmd("rightbelow vsplit")
			local b1 = vim.api.nvim_get_current_buf()
			vim.api.nvim_buf_set_name(
				b1,
				"fossil://" .. hash .. "/" .. vim.fn.fnamemodify(tgt, ":t") .. " - " .. tostring(os.time())
			)
			vim.api.nvim_buf_set_lines(b1, 0, -1, false, out1)
			if ft then
				vim.api.nvim_set_option_value("filetype", ft, { buf = b1 })
			end
			vim.api.nvim_set_option_value("buftype", "nofile", { buf = b1 })
			vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = b1 })
			vim.api.nvim_set_option_value("swapfile", false, { buf = b1 })
			vim.api.nvim_set_option_value("modifiable", false, { buf = b1 })
			vim.cmd("diffthis")
		else
			vim.notify("Failed to get file contents for diff.", vim.log.levels.ERROR)
		end
	end, opts)

	vim.keymap.set("n", "q", "<cmd>q<cr>", opts)
end

return M
