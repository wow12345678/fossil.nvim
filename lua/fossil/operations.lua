local api = require("fossil.api")
local util = require("fossil.util")
local window = require("fossil.ui.window")

local M = {}

function M.diff(args)
	local output, code = api.exec(args)
	local buf = window.open_scratch_buffer("Fossil diff", output)
	vim.api.nvim_set_option_value("filetype", "diff", { buf = buf })
end

function M.read(args)
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

	local output, code = api.exec({ "cat", target })
	if code ~= 0 then
		vim.notify("Fossil read failed.", vim.log.levels.ERROR)
		return
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, output)
	vim.api.nvim_set_option_value("modified", false, { buf = buf })
	vim.notify("Read " .. target .. " from fossil.", vim.log.levels.INFO)
end

function M.write(args)
	local filename = args[2] or vim.api.nvim_buf_get_name(0)
	if filename == "" then
		vim.notify("No file to write.", vim.log.levels.WARN)
		return
	end
	local target = util.resolve_target_path(filename) or filename

	vim.cmd("write")
	local _, code = api.exec({ "add", target })
	if code == 0 then
		vim.notify("Wrote and added " .. target .. " to fossil.", vim.log.levels.INFO)
	else
		vim.notify("Wrote file, but fossil add failed.", vim.log.levels.ERROR)
	end
end

function M.edit(args)
	local filename = args[2] or vim.api.nvim_buf_get_name(0)
	if filename == "" then
		vim.notify("No file to edit.", vim.log.levels.WARN)
		return
	end
	local target = util.resolve_target_path(filename) or filename

	vim.cmd("edit " .. vim.fn.fnameescape(target))
end

function M.browse(args)
	local output, code = api.exec({ "remote" })
	if code ~= 0 or #output == 0 or output[1] == "" then
		vim.notify("No remote found or fossil remote failed.", vim.log.levels.ERROR)
		return
	end

	local remote = output[1]

	if remote:match("^http") then
		local filename = args[2]
		local url = remote
		if filename and filename ~= "" then
			local target = util.resolve_target_path(filename) or filename
			local root = util.get_repo_root()
			if root and target:sub(1, #root) == root then
				target = target:sub(#root + 2)
			end
			url = url .. "/finfo?name=" .. target
		end
		vim.ui.open(url)
	else
		vim.notify("Remote is not a standard HTTP(S) URL: " .. remote, vim.log.levels.WARN)
	end
end

function M.delete(args, keep_buffer)
	local filename = args[2] or vim.api.nvim_buf_get_name(0)
	if filename == "" then
		vim.notify("No file to delete.", vim.log.levels.WARN)
		return
	end
	local target = util.resolve_target_path(filename) or filename

	local out, code = api.exec({ "rm", "--hard", target })
	if code == 0 then
		vim.notify("Deleted " .. target, vim.log.levels.INFO)
		if not keep_buffer then
			local absolute_target = vim.fn.fnamemodify(target, ":p")
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_get_name(buf) == absolute_target then
					vim.cmd("bdelete! " .. buf)
					break
				end
			end
		end
		local has_status, status_mod = pcall(require, "fossil.ui.status")
		if has_status and status_mod.refresh then
			status_mod.refresh()
		end
	else
		vim.notify("Failed to delete " .. target .. ":\n" .. table.concat(out, "\n"), vim.log.levels.ERROR)
	end
end

function M.move(args)
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
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_get_name(buf) == filename then
				vim.cmd("bdelete! " .. buf)
				break
			end
		end
		local has_status, status_mod = pcall(require, "fossil.ui.status")
		if has_status and status_mod.refresh then
			status_mod.refresh()
		end
	else
		vim.notify("Failed to move:\n" .. table.concat(out, "\n"), vim.log.levels.ERROR)
	end
end

function M.cd(args, lcd)
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

function M.checkout(args)
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
		local has_status, status_mod = pcall(require, "fossil.ui.status")
		if has_status and status_mod.refresh then
			status_mod.refresh()
		end
	end)
end

function M.tag(args)
	if #args == 1 then
		local output, code = api.exec({ "tag", "list" })
		if code == 0 then
			window.open_scratch_buffer("Fossil Tags", output)
		else
			vim.notify("Failed to list tags:\n" .. table.concat(output, "\n"), vim.log.levels.ERROR)
		end
	elseif #args >= 3 and args[2] == "add" then
		local tag_name = args[3]
		local revision = args[4] or "tip"
		local out, code = api.exec({ "tag", "add", tag_name, revision })
		if code == 0 then
			vim.notify("Tag '" .. tag_name .. "' added to " .. revision, vim.log.levels.INFO)
		else
			vim.notify("Failed to add tag:\n" .. table.concat(out, "\n"), vim.log.levels.ERROR)
		end
	elseif #args >= 3 and args[2] == "delete" then
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

function M.show(args)
	local output, code = api.exec(args)
	if #output == 0 then
		vim.api.nvim_echo({ { "Fossil command executed successfully (no output).", "Normal" } }, false, {})
	else
		window.open_scratch_buffer("Fossil " .. table.concat(args, " "), output)
	end
end

function M.sync(args)
	vim.notify("Fossil " .. args[1] .. " running...", vim.log.levels.INFO)
	api.exec_async(args, nil, function(output, code)
		if code == 0 then
			vim.notify("Fossil " .. args[1] .. " complete.", vim.log.levels.INFO)
		else
			vim.notify("Fossil " .. args[1] .. " failed:\n" .. table.concat(output, "\n"), vim.log.levels.ERROR)
		end
		local has_status, status_mod = pcall(require, "fossil.ui.status")
		if has_status and status_mod.refresh then
			status_mod.refresh()
		end
	end)
end

function M.undo(args)
	api.exec_async({ "undo" }, nil, function(output, code)
		if code == 0 then
			vim.notify("Fossil undo complete:\n" .. table.concat(output, "\n"), vim.log.levels.INFO)
		else
			vim.notify("Fossil undo failed:\n" .. table.concat(output, "\n"), vim.log.levels.ERROR)
		end
		vim.cmd("checktime")
		local has_status, status_mod = pcall(require, "fossil.ui.status")
		if has_status and status_mod.refresh then
			status_mod.refresh()
		end
	end)
end

function M.redo(args)
	api.exec_async({ "redo" }, nil, function(output, code)
		if code == 0 then
			vim.notify("Fossil redo complete:\n" .. table.concat(output, "\n"), vim.log.levels.INFO)
		else
			vim.notify("Fossil redo failed:\n" .. table.concat(output, "\n"), vim.log.levels.ERROR)
		end
		vim.cmd("checktime")
		local has_status, status_mod = pcall(require, "fossil.ui.status")
		if has_status and status_mod.refresh then
			status_mod.refresh()
		end
	end)
end

function M.wq(args, force)
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

function M.edit_with_cmd(args, vim_cmd)
	local filename = args[2] or vim.api.nvim_buf_get_name(0)
	if filename == "" then
		vim.notify("No file specified.", vim.log.levels.WARN)
		return
	end
	local target = util.resolve_target_path(filename) or filename
	vim.cmd(vim_cmd .. " " .. vim.fn.fnameescape(target))
end

return M
