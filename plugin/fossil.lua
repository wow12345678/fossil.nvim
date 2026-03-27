if vim.g.loaded_fossil == 1 then
	return
end
vim.g.loaded_fossil = 1

local fossil_command = require("fossil.command")

-- The main :Fossil command
vim.api.nvim_create_user_command("Fossil", function(opts)
	fossil_command.execute(opts.fargs)
end, {
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
			"timeline",
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
end, { nargs = "*" })
vim.api.nvim_create_user_command("FossilBlame", function(opts)
	fossil_command.execute({ "blame", unpack(opts.fargs) })
end, { nargs = "*" })
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
	fossil_command.execute({ "difftool", unpack(opts.fargs) })
end, { nargs = "*" })
vim.api.nvim_create_user_command("FossilGrep", function(opts)
	fossil_command.execute({ "grep", unpack(opts.fargs) })
end, { nargs = "+" })
vim.api.nvim_create_user_command("FossilClog", function(opts)
	fossil_command.execute({ "clog", unpack(opts.fargs) })
end, { nargs = "*" })
vim.api.nvim_create_user_command("FossilRead", function(opts)
	fossil_command.execute({ "read", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilWrite", function(opts)
	fossil_command.execute({ "write", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilEdit", function(opts)
	fossil_command.execute({ "edit", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilBrowse", function(opts)
	fossil_command.execute({ "browse", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })

vim.api.nvim_create_user_command("FossilCheckout", function(opts)
	fossil_command.execute({ "checkout", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })

vim.api.nvim_create_user_command("FossilCo", function(opts)
	fossil_command.execute({ "checkout", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })

vim.api.nvim_create_user_command("FossilTag", function(opts)
	fossil_command.execute({ "tag", unpack(opts.fargs) })
end, { nargs = "*" })

vim.api.nvim_create_user_command("FossilShow", function(opts)
	fossil_command.execute({ "show", unpack(opts.fargs) })
end, { nargs = "*" })

vim.api.nvim_create_user_command("FossilInfo", function(opts)
	fossil_command.execute({ "info", unpack(opts.fargs) })
end, { nargs = "*" })

vim.api.nvim_create_user_command("FossilAdd", function(opts)
	fossil_command.execute({ "add", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilDelete", function(opts)
	fossil_command.execute({ "delete", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilRemove", function(opts)
	fossil_command.execute({ "delete", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilRm", function(opts)
	fossil_command.execute({ "delete", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FossilMove", function(opts)
	fossil_command.execute({ "move", unpack(opts.fargs) })
end, { nargs = "+", complete = "file" })
vim.api.nvim_create_user_command("FossilCd", function()
	fossil_command.execute({ "cd" })
end, {})
vim.api.nvim_create_user_command("FossilLcd", function()
	fossil_command.execute({ "lcd" })
end, {})
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
