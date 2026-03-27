local api = require("fossil.api")
local util = require("fossil.util")

local M = {}

--- Open a blame view for the current file or given path
--- @param args table The command arguments
function M.open_blame_view(args)
	local target = args[2] or vim.api.nvim_buf_get_name(0)
	if target == "" then
		vim.notify("No file for blame.", vim.log.levels.WARN)
		return
	end

	local filename = util.resolve_target_path(target) or target
	local output, code = api.exec({ "blame", filename })
	if code ~= 0 then
		vim.notify("Fossil blame failed.", vim.log.levels.ERROR)
		return
	end

	vim.cmd("vsplit")
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_name(buf, "Fossil blame")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, output)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("filetype", "fossilblame", { buf = buf })
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	vim.api.nvim_set_option_value("scrollbind", true, { win = vim.api.nvim_get_current_win() })
	vim.api.nvim_set_option_value("cursorbind", true, { win = vim.api.nvim_get_current_win() })
	vim.cmd("wincmd p")
	vim.api.nvim_set_option_value("scrollbind", true, { win = vim.api.nvim_get_current_win() })
	vim.api.nvim_set_option_value("cursorbind", true, { win = vim.api.nvim_get_current_win() })

	vim.keymap.set("n", "gq", function()
		vim.cmd("wincmd p")
		vim.api.nvim_set_option_value("scrollbind", false, { win = vim.api.nvim_get_current_win() })
		vim.api.nvim_set_option_value("cursorbind", false, { win = vim.api.nvim_get_current_win() })
		vim.cmd("wincmd p")
		vim.api.nvim_set_option_value("scrollbind", false, { win = vim.api.nvim_get_current_win() })
		vim.api.nvim_set_option_value("cursorbind", false, { win = vim.api.nvim_get_current_win() })
		vim.cmd("bdelete")
	end, { buffer = buf, silent = true, noremap = true })
	vim.keymap.set("n", "q", "<cmd>bdelete<cr>", { buffer = buf, silent = true, noremap = true })
end

return M
