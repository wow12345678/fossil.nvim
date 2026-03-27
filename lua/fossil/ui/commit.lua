local api = require("fossil.api")

local M = {}

--- Prepare a commit buffer
function M.open_commit_buffer(args)
	vim.cmd("botright new")
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_name(buf, "Fossil Commit")

	local template = {
		"",
		"---------------------------------------------------",
		"Enter your commit message above. Lines starting with '-' are not ignored",
		"unless you configure fossil differently, but this is your editor.",
		"Save and quit (:wq) to commit, or quit without saving (:q!) to abort.",
	}

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, template)
	vim.api.nvim_set_option_value("buftype", "acwrite", { buf = buf })
	vim.api.nvim_set_option_value("filetype", "fossilcommit", { buf = buf })

	-- Autocmd to handle the actual commit on buffer write/close
	-- This is a simplified version; real fugitive handles this securely.
	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = buf,
		callback = function()
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			local msg = {}
			for _, line in ipairs(lines) do
				if line == "---------------------------------------------------" then
					break
				end
				table.insert(msg, line)
			end

			-- Write message to a temp file
			local tmp = os.tmpname()
			local f = io.open(tmp, "w")
			if f then
				f:write(table.concat(msg, "\n"))
				f:close()

				-- Run fossil commit -M tmp
				local commit_args = { "commit", "-M", tmp }
				-- Add any extra args passed
				for i = 2, #args do
					table.insert(commit_args, args[i])
				end

				local out, code = api.exec(commit_args)
				os.remove(tmp)

				if code == 0 then
					vim.notify("Fossil commit successful", vim.log.levels.INFO)
					vim.api.nvim_set_option_value("modified", false, { buf = buf })
					vim.cmd("bdelete")
				else
					vim.notify("Fossil commit failed:\n" .. table.concat(out, "\n"), vim.log.levels.ERROR)
				end
			end
		end,
	})
end

return M
