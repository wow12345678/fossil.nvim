if vim.g.loaded_fossil == 1 then
	return
end
vim.g.loaded_fossil = 1

local fossil_command = require("fossil.command")

-- The main :Fossil command
vim.api.nvim_create_user_command("Fossil", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute(args)
end, {
	bang = true,
	nargs = "*",
	complete = function(arglead, cmdline, cursorpos)
		-- Optional: add completion for common fossil commands like status, diff, commit, add, rm
		local cmds = {
			"status",
			"diff",
			"commit",
			"add",
			"rm",
			"info",
			"branch",
			"ticket",
			"wiki",
			"timeline",
			"finfo",
			"blame",
			"annotate",
			"diffsplit",
			"vdiffsplit",
			"hdiffsplit",
			"difftool",
			"grep",
			"clog",
			"read",
			"write",
			"edit",
			"browse",
			"checkout",
			"co",
			"tag",
			"show",
			"undo",
			"redo",
			"push",
			"pull",
			"sync",
			"fetch",
		}
		local matches = {}
		for _, cmd in ipairs(cmds) do
			if cmd:find("^" .. arglead) then
				table.insert(matches, cmd)
			end
		end
		return matches
	end,
	desc = "Run a fossil command or open the status window (like :Git)",
})

-- Shortcuts
vim.api.nvim_create_user_command("FossilStatus", function()
	fossil_command.execute({ "status" })
end, {})
vim.api.nvim_create_user_command("FossilCommit", function(opts)
	fossil_command.execute({ "commit", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilBlame", function(opts)
	fossil_command.execute({ "blame", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilDiffsplit", function(opts)
	fossil_command.execute({ "diffsplit", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilVdiffsplit", function(opts)
	fossil_command.execute({ "vdiffsplit", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilHdiffsplit", function(opts)
	fossil_command.execute({ "hdiffsplit", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilDifftool", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "difftool", unpack(args) })
end, { bang = true, nargs = "*" })
vim.api.nvim_create_user_command("FossilMergetool", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "mergetool", unpack(args) })
end, { bang = true, nargs = "*" })
vim.api.nvim_create_user_command("FossilGrep", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "grep", unpack(args) })
end, { bang = true, nargs = "+" })
vim.api.nvim_create_user_command("FossilClog", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "clog", unpack(args) })
end, { bang = true, nargs = "*" })
vim.api.nvim_create_user_command("FossilRead", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "read", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilWrite", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "write", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilEdit", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "edit", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilBrowse", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "browse", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilCheckout", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "checkout", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilBranch", function(opts)
	fossil_command.execute({ "branch", unpack(opts.fargs) })
end, { nargs = "*" })
vim.api.nvim_create_user_command("FossilTicket", function(opts)
	fossil_command.execute({ "ticket", unpack(opts.fargs) })
end, { nargs = "*" })
vim.api.nvim_create_user_command("FossilWiki", function(opts)
	fossil_command.execute({ "wiki", unpack(opts.fargs) })
end, { nargs = "*" })
vim.api.nvim_create_user_command("FossilTimeline", function(opts)
	fossil_command.execute({ "timeline", unpack(opts.fargs) })
end, { nargs = "*" })
vim.api.nvim_create_user_command("FossilFinfo", function(opts)
	fossil_command.execute({ "finfo", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilUndo", function(opts)
	fossil_command.execute({ "undo", unpack(opts.fargs) })
end, { nargs = "*" })
vim.api.nvim_create_user_command("FossilRedo", function(opts)
	fossil_command.execute({ "redo", unpack(opts.fargs) })
end, { nargs = "*" })
vim.api.nvim_create_user_command("FossilCo", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "checkout", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilTag", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "tag", unpack(args) })
end, { bang = true, nargs = "*" })
vim.api.nvim_create_user_command("FossilShow", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "show", unpack(args) })
end, { bang = true, nargs = "*" })
vim.api.nvim_create_user_command("FossilInfo", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "info", unpack(args) })
end, { bang = true, nargs = "*" })
vim.api.nvim_create_user_command("FossilAdd", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "add", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilDelete", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "delete", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilRemove", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "delete", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilRm", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "delete", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilUnlink", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "unlink", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilMove", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "move", unpack(args) })
end, { bang = true, nargs = "+", complete = "file" })
vim.api.nvim_create_user_command("FossilRename", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "rename", unpack(args) })
end, { bang = true, nargs = "+", complete = "file" })
vim.api.nvim_create_user_command("FossilCd", function()
	fossil_command.execute({ "cd" })
end, {})
vim.api.nvim_create_user_command("FossilLcd", function()
	fossil_command.execute({ "lcd" })
end, {})
vim.api.nvim_create_user_command("FossilSplit", function(opts)
	fossil_command.execute({ "split", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilVsplit", function(opts)
	fossil_command.execute({ "vsplit", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilTabedit", function(opts)
	fossil_command.execute({ "tabedit", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilPedit", function(opts)
	fossil_command.execute({ "pedit", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilDrop", function(opts)
	fossil_command.execute({ "drop", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilLgrep", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "lgrep", unpack(args) })
end, { bang = true, nargs = "+" })
vim.api.nvim_create_user_command("FossilGllog", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "gllog", unpack(args) })
end, { bang = true, nargs = "*" })
vim.api.nvim_create_user_command("FossilWq", function(opts)
	local args = vim.deepcopy(opts.fargs)
	if opts.bang then
		table.insert(args, 1, "!")
	end
	fossil_command.execute({ "wq", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilPush", function(opts)
	fossil_command.execute({ "push", unpack(opts.fargs) })
end, { nargs = "*" })
vim.api.nvim_create_user_command("FossilPull", function(opts)
	fossil_command.execute({ "pull", unpack(opts.fargs) })
end, { nargs = "*" })
vim.api.nvim_create_user_command("FossilSync", function(opts)
	fossil_command.execute({ "sync", unpack(opts.fargs) })
end, { nargs = "*" })
vim.api.nvim_create_user_command("FossilFetch", function(opts)
	fossil_command.execute({ "fetch", unpack(opts.fargs) })
end, { nargs = "*" })

if vim.g.fossil_no_maps ~= 1 then
	vim.keymap.set("n", "y<C-G>", function()
		local path = require("fossil.util").get_relative_path()
		if path ~= "" then
			vim.fn.setreg('"', path)
			vim.fn.setreg("0", path)
			vim.notify("Yanked: " .. path, vim.log.levels.INFO)
		end
	end, { desc = "Yank fossil relative path" })

	vim.keymap.set("c", "<C-R><C-G>", function()
		return require("fossil.util").get_relative_path()
	end, { expr = true, desc = "Insert fossil relative path" })
end

-- Statusline integration
local statusline_cache = {}

--- Returns a string suitable for inclusion in the statusline, caching the result
--- @return string
function _G.FossilStatusline()
	local root = require("fossil.util").get_repo_root()
	if not root then
		return ""
	end

	local now = vim.uv.now()
	local cache = statusline_cache[root]

	if cache and (now - cache.time < 5000) then
		return cache.text
	end

	local output, code = require("fossil.api").exec({ "branch", "current" })
	if code == 0 and output[1] then
		local text = "[Fossil(" .. output[1] .. ")]"
		statusline_cache[root] = { time = now, text = text }
		return text
	end

	return ""
end
