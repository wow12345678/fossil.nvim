local api = require("fossil.api")
local window = require("fossil.ui.window")

local M = {}

-- Cache for dropdown field values extracted from fossil config
local cached_dropdown_fields = nil

--- Parse tab separated ticket line
local function parse_tsv(line)
    return vim.split(line, "\t", { plain = true })
end

--- Get a random available port
local function get_free_port()
    local server = vim.loop.new_tcp()
    server:bind("127.0.0.1", 0)
    local port = server:getsockname().port
    server:close()
    return port
end

--- Fetch ticket dropdown choices from Fossil's tktsetup_com page
local function fetch_ticket_choices(callback)
    if cached_dropdown_fields then
        callback(cached_dropdown_fields)
        return
    end

    local port = get_free_port()
    -- Start fossil ui server in the background
    local ui_job = vim.fn.jobstart({ "fossil", "ui", "--port", tostring(port), "--nobrowser" }, {
        on_exit = function() end,
    })

    -- Give the server a moment to start
    vim.defer_fn(function()
        local curl_job = vim.fn.jobstart({ "curl", "-s", "http://localhost:" .. port .. "/tktsetup_com" }, {
            stdout_buffered = true,
            on_stdout = function(_, data)
                local content = table.concat(data, "\n")

                -- Stop the server
                vim.fn.jobstop(ui_job)

                local dropdown_fields = {
                    status = {},
                    type = {},
                    severity = {},
                    priority = {},
                    resolution = {},
                    subsystem = {},
                }

                -- Parse the TH1 script variables: set variable_name { values... }
                for var_name, values_block in content:gmatch("set ([%w_]+) %{([^}]*)%}") do
                    local field_match = var_name:match("^(%w+)_choices$")
                    if field_match and dropdown_fields[field_match] then
                        for value in values_block:gmatch("%S+") do
                            table.insert(dropdown_fields[field_match], value)
                        end
                    end
                end

                cached_dropdown_fields = dropdown_fields
                callback(dropdown_fields)
            end,
            on_stderr = function() end,
            on_exit = function(_, code)
                if code ~= 0 then
                    vim.fn.jobstop(ui_job)
                    -- Fallback if curl fails
                    callback({
                        status = { "Open", "Verified", "Review", "Deferred", "Fixed", "Tested", "Closed" },
                        type = { "Code_Defect", "Build_Problem", "Documentation", "Feature_Request", "Incident" },
                        severity = { "Critical", "Severe", "Important", "Minor", "Cosmetic" },
                        priority = { "Immediate", "High", "Medium", "Low", "Zero" },
                        resolution = {
                            "Open",
                            "Fixed",
                            "Rejected",
                            "Workaround",
                            "Unable_To_Reproduce",
                            "Works_As_Designed",
                        },
                        subsystem = {},
                    })
                end
            end,
        })
    end, 500)
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
        local idx_uuid, idx_type, idx_status, idx_title
        local idx_severity, idx_priority, idx_resolution, idx_subsystem, idx_contact, idx_foundin, idx_comment
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
            if h == "severity" then
                idx_severity = i
            end
            if h == "priority" then
                idx_priority = i
            end
            if h == "resolution" then
                idx_resolution = i
            end
            if h == "subsystem" then
                idx_subsystem = i
            end
            if h == "private_contact" then
                idx_contact = i
            end
            if h == "foundin" then
                idx_foundin = i
            end
            if h == "comment" then
                idx_comment = i
            end
        end

        if idx_uuid and idx_title then
            local header_str = string.format(
                " %-10s | %-10s | %-10s | %-10s | %-10s | %-15s | %-15s | %-15s | %-15s | %-30s | %s",
                "UUID",
                "Type",
                "Status",
                "Severity",
                "Priority",
                "Resolution",
                "Subsystem",
                "Contact",
                "Version Found",
                "Title",
                "Comment"
            )
            table.insert(lines, header_str)
            table.insert(lines, string.rep("-", 170))

            for i = 2, #output do
                local row = parse_tsv(output[i])
                if #row >= idx_uuid then
                    local uuid = string.sub(row[idx_uuid] or "", 1, 10)
                    local ttype = string.sub(row[idx_type] or "", 1, 10)
                    local status = string.sub(row[idx_status] or "", 1, 10)
                    local severity = string.sub(row[idx_severity] or "", 1, 10)
                    local priority = string.sub(row[idx_priority] or "", 1, 10)
                    local resolution = string.sub(row[idx_resolution] or "", 1, 15)
                    local subsystem = string.sub(row[idx_subsystem] or "", 1, 15)
                    local contact = string.sub(row[idx_contact] or "", 1, 15)
                    local foundin = string.sub(row[idx_foundin] or "", 1, 15)
                    local title = string.sub(row[idx_title] or "", 1, 30)
                    local comment = row[idx_comment] or ""

                    -- remove newlines from comment so it displays on one line
                    comment = comment:gsub("\r", ""):gsub("\n", " ")

                    local line_str = string.format(
                        " %-10s | %-10s | %-10s | %-10s | %-10s | %-15s | %-15s | %-15s | %-15s | %-30s | %s",
                        uuid,
                        ttype,
                        status,
                        severity,
                        priority,
                        resolution,
                        subsystem,
                        contact,
                        foundin,
                        title,
                        comment
                    )
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
        local out_show, c_show = api.exec({ "ticket", "show", "0" })
        if c_show ~= 0 or #out_show == 0 then
            vim.notify("Failed to get ticket format.", vim.log.levels.ERROR)
            return
        end
        local all_headers = parse_tsv(out_show[1])
        local fields = { "title" }
        for _, h in ipairs(all_headers) do
            if h ~= "tkt_id" and h ~= "tkt_uuid" and h ~= "tkt_mtime" and h ~= "tkt_ctime" and h ~= "title" then
                table.insert(fields, h)
            end
        end

        local args = { "ticket", "add" }

        local function prompt_field(idx)
            if idx > #fields then
                if #args > 2 then
                    local out, c = api.exec(args)
                    if c == 0 then
                        vim.notify("Created ticket.", vim.log.levels.INFO)
                        vim.cmd("q")
                        M.open_ticket_window()
                    else
                        vim.notify("Failed to create ticket:\n" .. table.concat(out, "\n"), vim.log.levels.ERROR)
                    end
                else
                    vim.notify("No fields provided, ticket creation cancelled.", vim.log.levels.WARN)
                end
                return
            end

            local field = fields[idx]
            local prompt_text = "Value for " .. field .. " (leave empty to skip): "
            if field == "title" then
                prompt_text = "Title (required): "
            end

            vim.ui.input({ prompt = prompt_text }, function(val)
                -- If the user pressed Esc, val is nil. We should probably abort or skip?
                -- If they pressed enter without typing, val is "".
                if val == nil then
                    vim.notify("Ticket creation cancelled.", vim.log.levels.INFO)
                    return
                end

                if val ~= "" then
                    table.insert(args, field)
                    table.insert(args, val)
                elseif field == "title" then
                    vim.notify("Title is required. Ticket creation cancelled.", vim.log.levels.WARN)
                    return
                end
                vim.schedule(function()
                    prompt_field(idx + 1)
                end)
            end)
        end

        prompt_field(1)
    end, opts)

    -- Edit Ticket
    vim.keymap.set("n", "e", function()
        local uuid = get_uuid_under_cursor()
        if not uuid then
            return
        end

        local out_show, c_show = api.exec({ "ticket", "show", "0", "[tkt_uuid] LIKE '" .. uuid .. "%'" })
        if c_show == 0 and #out_show >= 2 then
            local headers = parse_tsv(out_show[1])
            local values = parse_tsv(out_show[2])

            vim.ui.select(headers, { prompt = "Field to edit: " }, function(field)
                if field and field ~= "" then
                    vim.schedule(function()
                        local old_value = ""
                        for i, h in ipairs(headers) do
                            if h == field then
                                old_value = values[i] or ""
                                break
                            end
                        end

                        fetch_ticket_choices(function(dropdown_fields)
                            vim.schedule(function()
                                local function update_ticket(val)
                                    if val and val ~= "" then
                                        local out, c = api.exec({ "ticket", "set", uuid, field, val })
                                        if c == 0 then
                                            vim.notify("Updated ticket.", vim.log.levels.INFO)
                                            vim.cmd("q")
                                            M.open_ticket_window()
                                        else
                                            vim.notify(
                                                "Failed to update ticket:\n" .. table.concat(out, "\n"),
                                                vim.log.levels.ERROR
                                            )
                                        end
                                    end
                                end

                                if dropdown_fields[field] then
                                    local query = string.format(
                                        "SELECT DISTINCT %s FROM ticket WHERE %s IS NOT NULL AND %s != '';",
                                        field,
                                        field,
                                        field
                                    )
                                    local opts_out, opts_c = api.exec({ "sql", query })

                                    local options_set = {}
                                    local options = {}

                                    -- Add default choices from tktsetup_com
                                    for _, opt in ipairs(dropdown_fields[field]) do
                                        if not options_set[opt] then
                                            table.insert(options, opt)
                                            options_set[opt] = true
                                        end
                                    end

                                    -- Add existing choices from repo
                                    if opts_c == 0 then
                                        for _, opt in ipairs(opts_out) do
                                            if not options_set[opt] then
                                                table.insert(options, opt)
                                                options_set[opt] = true
                                            end
                                        end
                                    end
                                    table.insert(options, "[Type custom value...]")

                                    vim.ui.select(
                                        options,
                                        { prompt = "Select new value for " .. field .. ": " },
                                        function(selected)
                                            vim.schedule(function()
                                                if selected == "[Type custom value...]" then
                                                    vim.ui.input(
                                                        {
                                                            prompt = "New value for " .. field .. ": ",
                                                            default = old_value,
                                                        },
                                                        update_ticket
                                                    )
                                                elseif selected then
                                                    update_ticket(selected)
                                                end
                                            end)
                                        end
                                    )
                                else
                                    vim.ui.input(
                                        { prompt = "New value for " .. field .. ": ", default = old_value },
                                        update_ticket
                                    )
                                end
                            end)
                        end)
                    end)
                end
            end)
        else
            vim.notify("Failed to load ticket fields.", vim.log.levels.ERROR)
        end
    end, opts)

    -- Quit
    vim.keymap.set("n", "q", "<cmd>q<cr>", opts)
end

return M
