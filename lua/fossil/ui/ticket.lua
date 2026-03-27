local api = require("fossil.api")
local window = require("fossil.ui.window")

local M = {}

--- Parse tab separated ticket line
local function parse_tsv(line)
	return vim.split(line, "\t", { plain = true })
end

--- Open a window to view and manage fossil tickets
function M.open_ticket_window()
	local output, code = api.exec({ "ticket", "show", "0" })
	if code ~= 0 then
		vim.notify("Failed to list tickets.", vim.log.levels.ERROR)
		return
	end

	vim.cmd("botright new")
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_name(buf, "Fossil Tickets - " .. tostring(os.time()))

	local lines = {
		"==================================================================",
		"|                    Fossil Tickets                              |",
		"==================================================================",
		" <CR>  View Ticket History under cursor",
		" c     Create a new Ticket",
		" e     Edit Ticket under cursor",
		" q     Close this window",
		"==================================================================",
		"",
	}

	-- Output typically has a header line:
	-- tkt_id \t tkt_uuid \t ...
	if #output > 0 then
		local headers = parse_tsv(output[1])
		-- We want to find index of: tkt_uuid, type, status, title
		local idx_uuid, idx_type, idx_status, idx_title
		for i, h in ipairs(headers) do
			if h == "tkt_uuid" then
				idx_uuid = i
			end
			if h == "type" then
				idx_type = i
			end
			if h == "status" then
				idx_status = i
			end
			if h == "title" then
				idx_title = i
			end
		end

		if idx_uuid and idx_title then
			local header_str = string.format(" %-12s | %-10s | %-10s | %s", "UUID", "Type", "Status", "Title")
			table.insert(lines, header_str)
			table.insert(lines, string.rep("-", 60))

			for i = 2, #output do
				local row = parse_tsv(output[i])
				if #row >= idx_uuid then
					local uuid = string.sub(row[idx_uuid] or "", 1, 10)
					local ttype = string.sub(row[idx_type] or "", 1, 10)
					local status = string.sub(row[idx_status] or "", 1, 10)
					local title = row[idx_title] or ""

					local line_str = string.format(" %-12s | %-10s | %-10s | %s", uuid, ttype, status, title)
					table.insert(lines, line_str)
				end
			end
		else
			for _, line in ipairs(output) do
				table.insert(lines, line)
			end
		end
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- Set buffer options
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	vim.api.nvim_set_option_value("filetype", "fossilticket", { buf = buf })

	local syntax_cmds = [[
		if exists("b:current_syntax")
		  finish
		endif

		syn match fossilTicketHeader "^====.*"
		syn match fossilTicketTitle "^|.*|$"
		syn match fossilTicketKey "^\s\+\S\+\s"

		hi def link fossilTicketHeader Comment
		hi def link fossilTicketTitle Type
		hi def link fossilTicketKey Special

		let b:current_syntax = "fossilticket"
	]]
	vim.cmd(syntax_cmds)

	local opts = { buffer = buf, silent = true, noremap = true }

	local function get_uuid_under_cursor()
		local line = vim.api.nvim_get_current_line()
		-- match " uuid "
		local uuid = line:match("^%s([0-9a-fA-F]+)%s+|")
		return uuid
	end

	-- View Ticket History
	vim.keymap.set("n", "<CR>", function()
		local uuid = get_uuid_under_cursor()
		if not uuid then
			return
		end
		local hist, hc = api.exec({ "ticket", "history", uuid })
		if hc == 0 then
			window.open_scratch_buffer("Ticket " .. uuid, hist)
		else
			vim.notify("Failed to get ticket history.", vim.log.levels.ERROR)
		end
	end, opts)

	-- Create Ticket
	vim.keymap.set("n", "c", function()
		vim.ui.input({ prompt = "New Ticket Title: " }, function(title)
			if title and title ~= "" then
				vim.ui.input({ prompt = "Ticket Type (e.g. Bug, Feature): " }, function(ttype)
					local type_val = (ttype and ttype ~= "") and ttype or "Feature"
					local out, c = api.exec({ "ticket", "add", "title", title, "type", type_val, "status", "Open" })
					if c == 0 then
						vim.notify("Created ticket.", vim.log.levels.INFO)
						vim.cmd("q")
						M.open_ticket_window()
					else
						vim.notify("Failed to create ticket:\n" .. table.concat(out, "\n"), vim.log.levels.ERROR)
					end
				end)
			end
		end)
	end, opts)

	-- Edit Ticket
	vim.keymap.set("n", "e", function()
		local uuid = get_uuid_under_cursor()
		if not uuid then
			return
		end
		vim.ui.input({ prompt = "Field to edit (e.g. status, title, type): " }, function(field)
			if field and field ~= "" then
				vim.ui.input({ prompt = "New value for " .. field .. ": " }, function(val)
					if val and val ~= "" then
						local out, c = api.exec({ "ticket", "set", uuid, field, val })
						if c == 0 then
							vim.notify("Updated ticket.", vim.log.levels.INFO)
							vim.cmd("q")
							M.open_ticket_window()
						else
							vim.notify("Failed to update ticket:\n" .. table.concat(out, "\n"), vim.log.levels.ERROR)
						end
					end
				end)
			end
		end)
	end, opts)

	-- Quit
	vim.keymap.set("n", "q", "<cmd>q<cr>", opts)
end

return M
