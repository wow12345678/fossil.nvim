local api = require("fossil.api")
local window = require("fossil.ui.window")

local M = {}

-- Cache for dropdown field values extracted from fossil config, keyed by repo path
local cached_dropdown_fields = {}

--- Parse tab separated ticket line
local function parse_tsv(line)
    return vim.split(line, "\t", { plain = true })
end

--- Get the root directory of the current fossil checkout
local function get_fossil_root()
    local out, code = api.exec({ "info" })
    if code == 0 then
        for _, line in ipairs(out) do
            local root = line:match("^local%-root:%s+(.+)$")
            if root then
                return root:gsub("/$", "")
            end
        end
    end
    return vim.fn.getcwd()
end

--- Get a random available port
local function get_free_port()
    local uv = vim.uv or vim.loop
    local server = uv.new_tcp()
    server:bind("127.0.0.1", 0)
    local port = server:getsockname().port
    server:close()
    return port
end

--- Fetch ticket dropdown choices from Fossil's tktsetup_com page
local function fetch_ticket_choices(callback)
    local repo_root = get_fossil_root()
    if cached_dropdown_fields[repo_root] then
        callback(cached_dropdown_fields[repo_root])
        return
    end

    local fallback_fields = {
        status = { "Open", "Verified", "Review", "Deferred", "Fixed", "Tested", "Closed" },
        type = { "Code_Defect", "Build_Problem", "Documentation", "Feature_Request", "Incident" },
        severity = { "Critical", "Severe", "Important", "Minor", "Cosmetic" },
        priority = { "Immediate", "High", "Medium", "Low", "Zero" },
        resolution = { "Open", "Fixed", "Rejected", "Workaround", "Unable_To_Reproduce", "Works_As_Designed" },
        subsystem = {},
    }

    local port = get_free_port()
    -- Start fossil ui server in the background
    local ui_job = vim.fn.jobstart({ "fossil", "ui", "--port", tostring(port), "--nobrowser" }, {
        on_exit = function() end,
    })

    -- Give the server a moment to start
    vim.defer_fn(function()
        local uv = vim.uv or vim.loop
        local client = uv.new_tcp()
        local stdout_data = {}

        local handled = false

        local function fallback_and_stop()
            if handled then
                return
            end
            handled = true

            if not client:is_closing() then
                client:close()
            end
            vim.fn.jobstop(ui_job)
            cached_dropdown_fields[repo_root] = fallback_fields
            callback(fallback_fields)
        end

        client:connect("127.0.0.1", port, function(err)
            if err then
                vim.schedule(fallback_and_stop)
                return
            end

            client:write(
                string.format("GET /tktsetup_com HTTP/1.0\r\nHost: 127.0.0.1:%d\r\nConnection: close\r\n\r\n", port)
            )

            client:read_start(function(read_err, chunk)
                if read_err then
                    vim.schedule(fallback_and_stop)
                    return
                end

                if chunk then
                    table.insert(stdout_data, chunk)
                else
                    if handled then
                        return
                    end
                    handled = true

                    client:close()
                    vim.schedule(function()
                        vim.fn.jobstop(ui_job)

                        local content = table.concat(stdout_data, "")

                        -- Only parse within the active textarea to avoid picking up the default script examples
                        local textarea_content = content:match('<textarea[^>]*name="x"[^>]*>(.-)</textarea>')
                        if not textarea_content then
                            cached_dropdown_fields[repo_root] = fallback_fields
                            callback(fallback_fields)
                            return
                        end

                        local dropdown_fields = {
                            status = {},
                            type = {},
                            severity = {},
                            priority = {},
                            resolution = {},
                            subsystem = {},
                        }

                        -- Parse the TH1 script variables: set variable_name { values... }
                        for var_name, values_block in textarea_content:gmatch("set ([%w_]+) %{([^}]*)%}") do
                            local field_match = var_name:match("^(%w+)_choices$")
                            if field_match and dropdown_fields[field_match] then
                                for value in values_block:gmatch("%S+") do
                                    table.insert(dropdown_fields[field_match], value)
                                end
                            end
                        end

                        cached_dropdown_fields[repo_root] = dropdown_fields
                        callback(dropdown_fields)
                    end)
                end
            end)
        end)

        -- Fallback timeout (e.g. 5 seconds) just in case server hangs
        vim.defer_fn(function()
            if not handled and not client:is_closing() then
                fallback_and_stop()
            end
        end, 5000)
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

    local filter_state = {
        status = nil,
        type = nil,
        severity = nil,
        priority = nil,
        resolution = nil,
        search = nil,
    }

    local all_tickets = {}
    local headers = {}
    local col_indices = {}

    if #output > 0 then
        headers = parse_tsv(output[1])
        for i, h in ipairs(headers) do
            col_indices[h] = i
        end

        for i = 2, #output do
            local row = parse_tsv(output[i])
            if #row >= (col_indices["tkt_uuid"] or 1) then
                local ticket = {
                    uuid = string.sub(row[col_indices["tkt_uuid"]] or "", 1, 10),
                    type = string.sub(row[col_indices["type"]] or "", 1, 10),
                    status = string.sub(row[col_indices["status"]] or "", 1, 10),
                    severity = string.sub(row[col_indices["severity"]] or "", 1, 10),
                    priority = string.sub(row[col_indices["priority"]] or "", 1, 10),
                    resolution = string.sub(row[col_indices["resolution"]] or "", 1, 15),
                    subsystem = string.sub(row[col_indices["subsystem"]] or "", 1, 15),
                    contact = string.sub(row[col_indices["private_contact"]] or "", 1, 15),
                    foundin = string.sub(row[col_indices["foundin"]] or "", 1, 15),
                    title = string.sub(row[col_indices["title"]] or "", 1, 30),
                    comment = (row[col_indices["comment"]] or ""):gsub("\r", ""):gsub("\n", " "),
                }
                table.insert(all_tickets, ticket)
            end
        end
    end

    local function render()
        local lines = {
            "==================================================================",
            "|                    Fossil Tickets                              |",
            "==================================================================",
            " <CR> View   c Create   e Edit   q Quit",
            " fs Status  ft Type  fv Severity  fp Priority  fr Resolution",
            " /  Search  x  Clear filters",
            "==================================================================",
        }

        local active_filters = {}
        if filter_state.status then
            table.insert(active_filters, "Status=" .. filter_state.status)
        end
        if filter_state.type then
            table.insert(active_filters, "Type=" .. filter_state.type)
        end
        if filter_state.severity then
            table.insert(active_filters, "Severity=" .. filter_state.severity)
        end
        if filter_state.priority then
            table.insert(active_filters, "Priority=" .. filter_state.priority)
        end
        if filter_state.resolution then
            table.insert(active_filters, "Resolution=" .. filter_state.resolution)
        end
        if filter_state.search then
            table.insert(active_filters, 'Search="' .. filter_state.search .. '"')
        end

        local filter_str = table.concat(active_filters, ", ")
        if filter_str == "" then
            filter_str = "None"
        end

        local filtered_tickets = {}
        for _, t in ipairs(all_tickets) do
            local match = true
            if filter_state.status and t.status ~= string.sub(filter_state.status, 1, 10) then
                match = false
            end
            if filter_state.type and t.type ~= string.sub(filter_state.type, 1, 10) then
                match = false
            end
            if filter_state.severity and t.severity ~= string.sub(filter_state.severity, 1, 10) then
                match = false
            end
            if filter_state.priority and t.priority ~= string.sub(filter_state.priority, 1, 10) then
                match = false
            end
            if filter_state.resolution and t.resolution ~= string.sub(filter_state.resolution, 1, 15) then
                match = false
            end

            if match and filter_state.search then
                local search_lower = filter_state.search:lower()
                local t_lower = t.title:lower()
                local c_lower = t.comment:lower()
                local cont_lower = t.contact:lower()
                if
                    not (
                        t_lower:find(search_lower, 1, true)
                        or c_lower:find(search_lower, 1, true)
                        or cont_lower:find(search_lower, 1, true)
                    )
                then
                    match = false
                end
            end

            if match then
                table.insert(filtered_tickets, t)
            end
        end

        local count_str = string.format("[%d of %d]", #filtered_tickets, #all_tickets)
        table.insert(lines, string.format(" Filters: %-46s %s", string.sub(filter_str, 1, 46), count_str))
        table.insert(lines, "==================================================================")
        table.insert(lines, "")

        if col_indices["tkt_uuid"] and col_indices["title"] then
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

            for _, t in ipairs(filtered_tickets) do
                local line_str = string.format(
                    " %-10s | %-10s | %-10s | %-10s | %-10s | %-15s | %-15s | %-15s | %-15s | %-30s | %s",
                    t.uuid,
                    t.type,
                    t.status,
                    t.severity,
                    t.priority,
                    t.resolution,
                    t.subsystem,
                    t.contact,
                    t.foundin,
                    t.title,
                    t.comment
                )
                table.insert(lines, line_str)
            end
        else
            if #filtered_tickets == #all_tickets then
                for i = 2, #output do
                    table.insert(lines, output[i])
                end
            else
                table.insert(lines, "Cannot filter unrecognised ticket format.")
            end
        end

        vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    end

    render()

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

        fetch_ticket_choices(function(dropdown_fields)
            vim.schedule(function()
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

                    local function handle_input(val)
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

                        for _, opt in ipairs(dropdown_fields[field]) do
                            if not options_set[opt] then
                                table.insert(options, opt)
                                options_set[opt] = true
                            end
                        end

                        if opts_c == 0 then
                            for _, opt in ipairs(opts_out) do
                                if not options_set[opt] then
                                    table.insert(options, opt)
                                    options_set[opt] = true
                                end
                            end
                        end
                        table.insert(options, "[Type custom value...]")

                        vim.ui.select(options, { prompt = prompt_text }, function(selected)
                            vim.schedule(function()
                                if selected == nil then
                                    handle_input(nil)
                                elseif selected == "[Type custom value...]" then
                                    vim.ui.input({ prompt = prompt_text }, handle_input)
                                else
                                    handle_input(selected)
                                end
                            end)
                        end)
                    else
                        vim.ui.input({ prompt = prompt_text }, handle_input)
                    end
                end

                prompt_field(1)
            end)
        end)
    end, opts)

    -- Edit Ticket
    vim.keymap.set("n", "e", function()
        local uuid = get_uuid_under_cursor()
        if not uuid then
            return
        end

        local out_show, c_show = api.exec({ "ticket", "show", "0", "[tkt_uuid] LIKE '" .. uuid .. "%'" })
        if c_show == 0 and #out_show >= 2 then
            local file_headers = parse_tsv(out_show[1])
            local values = parse_tsv(out_show[2])

            vim.ui.select(file_headers, { prompt = "Field to edit: " }, function(field)
                if field and field ~= "" then
                    vim.schedule(function()
                        local old_value = ""
                        for i, h in ipairs(file_headers) do
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

                                    for _, opt in ipairs(dropdown_fields[field]) do
                                        if not options_set[opt] then
                                            table.insert(options, opt)
                                            options_set[opt] = true
                                        end
                                    end

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
                                                    vim.ui.input({
                                                        prompt = "New value for " .. field .. ": ",
                                                        default = old_value,
                                                    }, update_ticket)
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

    local function apply_dropdown_filter(field, title)
        fetch_ticket_choices(function(dropdown_fields)
            vim.schedule(function()
                local options_set = {}
                local options = {}

                if dropdown_fields[field] then
                    for _, opt in ipairs(dropdown_fields[field]) do
                        if not options_set[opt] then
                            table.insert(options, opt)
                            options_set[opt] = true
                        end
                    end
                end

                local query = string.format(
                    "SELECT DISTINCT %s FROM ticket WHERE %s IS NOT NULL AND %s != '';",
                    field,
                    field,
                    field
                )
                local opts_out, opts_c = api.exec({ "sql", query })
                if opts_c == 0 then
                    for _, opt in ipairs(opts_out) do
                        if not options_set[opt] then
                            table.insert(options, opt)
                            options_set[opt] = true
                        end
                    end
                end

                if #options == 0 then
                    vim.notify("No values found for " .. title, vim.log.levels.WARN)
                    return
                end

                table.insert(options, 1, "[Clear Filter]")

                vim.ui.select(options, { prompt = "Filter by " .. title .. ": " }, function(selected)
                    if not selected then
                        return
                    end
                    vim.schedule(function()
                        if selected == "[Clear Filter]" then
                            filter_state[field] = nil
                        else
                            filter_state[field] = selected
                        end
                        render()
                    end)
                end)
            end)
        end)
    end

    vim.keymap.set("n", "fs", function()
        apply_dropdown_filter("status", "Status")
    end, opts)
    vim.keymap.set("n", "ft", function()
        apply_dropdown_filter("type", "Type")
    end, opts)
    vim.keymap.set("n", "fv", function()
        apply_dropdown_filter("severity", "Severity")
    end, opts)
    vim.keymap.set("n", "fp", function()
        apply_dropdown_filter("priority", "Priority")
    end, opts)
    vim.keymap.set("n", "fr", function()
        apply_dropdown_filter("resolution", "Resolution")
    end, opts)

    vim.keymap.set("n", "/", function()
        vim.ui.input({ prompt = "Search tickets: ", default = filter_state.search or "" }, function(val)
            if val == nil then
                return
            end
            vim.schedule(function()
                if val == "" then
                    filter_state.search = nil
                else
                    filter_state.search = val
                end
                render()
            end)
        end)
    end, opts)

    vim.keymap.set("n", "x", function()
        filter_state.status = nil
        filter_state.type = nil
        filter_state.severity = nil
        filter_state.priority = nil
        filter_state.resolution = nil
        filter_state.search = nil
        render()
        vim.notify("Filters cleared", vim.log.levels.INFO)
    end, opts)

    -- Quit
    vim.keymap.set("n", "q", "<cmd>q<cr>", opts)
end

return M
