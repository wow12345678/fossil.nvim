local api = require("fossil.api")

local M = {}

--- Parse fossil status and extras into a structured format asynchronously
--- @param callback function Called with the structured lines
local function get_status_lines_async(callback)
    api.exec_async({ "status" }, nil, function(status_out, code)
        if code ~= 0 then
            callback({ "Not in a fossil repository." })
            return
        end

        local lines = {}
        local head = "unknown"
        local checkout_hash = ""

        -- Extract header info
        for _, line in ipairs(status_out) do
            if line:match("^[A-Z]+") then
                break -- Start of file changes
            end
            local tags = line:match("^tags:%s+(.*)")
            if tags then
                head = tags
            end
            local chk = line:match("^checkout:%s+(%w+)")
            if chk then
                checkout_hash = string.sub(chk, 1, 10)
            end
        end

        if checkout_hash ~= "" then
            head = head .. " (" .. checkout_hash .. ")"
        end

        table.insert(lines, "Head: " .. head)

        api.exec_async({ "remote" }, nil, function(remote_out, r_code)
            if r_code == 0 and #remote_out > 0 and remote_out[1] ~= "off" then
                table.insert(lines, "Remote: " .. remote_out[1])
            end

            table.insert(lines, "Help: g?")
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
            api.exec_async({ "extras" }, nil, function(extras_out)
                if #extras_out > 0 then
                    table.insert(lines, "Untracked:")
                    for _, file in ipairs(extras_out) do
                        table.insert(lines, "  ? " .. file)
                    end
                end
                callback(lines)
            end)
        end)
    end, { quiet = true })
end

--- Unstage all added files
--- @return nil
local function unstage_all()
    api.exec_async({ "status" }, nil, function(status_out)
        local added_files = {}
        for _, line in ipairs(status_out) do
            local filename = line:match("^%s+ADDED%s+(.+)$")
            if filename then
                table.insert(added_files, filename)
            end
        end
        if #added_files > 0 then
            local args = { "rm", "--soft" }
            for _, f in ipairs(added_files) do
                table.insert(args, f)
            end
            api.exec_async(args, nil, function()
                M.refresh()
                vim.notify("Unstaged " .. #added_files .. " files.", vim.log.levels.INFO)
            end)
        else
            vim.notify("Nothing to unstage.", vim.log.levels.INFO)
        end
    end)
end

--- Jump to a section matching a pattern
--- @param header_pattern string The pattern to match
--- @return nil
local function jump_to_section(header_pattern)
    local lines = vim.api.nvim_buf_get_lines(M.buf, 0, -1, false)
    for i, line in ipairs(lines) do
        if line:match(header_pattern) then
            vim.api.nvim_win_set_cursor(0, { i, 0 })
            return
        end
    end
end

--- Run an action on the file under cursor
--- @param filename string The file to open
--- @param mode string The mode to open it with (e.g. "split", "vsplit", "tab", "pedit", "edit")
--- @return nil
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

local INLINE_PREFIX = "    "

--- Check if a line is an inline diff line
--- @param line string The line content
--- @return boolean
local function is_inline_diff_line(line)
    return line:sub(1, #INLINE_PREFIX) == INLINE_PREFIX
end

--- Check if a line contains a file state
--- @param line string The line content
--- @return boolean
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

--- Get a file from a string line in the status window
--- @param line string The line content
--- @return string|nil filename The filename
--- @return string|nil state The state of the file (e.g. "ADDED", "EDITED", "UNTRACKED")
local function parse_file_line(line)
    -- Match "  ADDED      filename" or "  EDITED     filename"
    local state, filename = line:match("^%s+([A-Z]+)%s+(.+)$")
    if state and filename then
        return filename, state
    end

    -- Match "  ? filename"
    local untracked_file = line:match("^%s+%?%s+(.+)$")
    if untracked_file then
        return untracked_file, "UNTRACKED"
    end

    return nil, nil
end

--- Jump to next or previous file in the status buffer
--- @param direction number 1 for next, -1 for previous
--- @return nil
local function jump_to_file(direction)
    local line_nr = vim.api.nvim_win_get_cursor(0)[1]
    local lines = vim.api.nvim_buf_get_lines(M.buf, 0, -1, false)

    local current = line_nr + direction
    while current > 0 and current <= #lines do
        local line = lines[current]
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
        local lines = vim.api.nvim_buf_get_lines(M.buf, 0, line_nr - 1, false)
        while line_nr > 1 do
            line_nr = line_nr - 1
            line = lines[line_nr]
            if not is_inline_diff_line(line) then
                break
            end
        end
    end

    local filename, state = parse_file_line(line)
    if filename then
        return filename, state, line_nr
    end

    return nil, nil, nil
end

--- Remove inline diff for a file
--- @param line_nr number The starting line number of the file entry
--- @return nil
local function inline_diff_remove(line_nr)
    local lines = vim.api.nvim_buf_get_lines(M.buf, line_nr, -1, false)
    local stop = line_nr
    for _, line in ipairs(lines) do
        if not is_inline_diff_line(line) then
            break
        end
        stop = stop + 1
    end

    if stop > line_nr then
        vim.api.nvim_set_option_value("modifiable", true, { buf = M.buf })
        vim.api.nvim_buf_set_lines(M.buf, line_nr, stop, false, {})
        vim.api.nvim_set_option_value("modifiable", false, { buf = M.buf })
    end
end

--- Insert inline diff for a file
--- @param line_nr number The line number where the file is listed
--- @param filename string The file to diff
--- @param state string The state of the file
--- @return nil
local function inline_diff_insert(line_nr, filename, state)
    if state == "UNTRACKED" then
        vim.notify("Cannot diff untracked file.", vim.log.levels.WARN)
        return
    end

    api.exec_async({ "diff", "--unified", filename }, nil, function(diff_lines)
        if #diff_lines == 0 then
            vim.notify("No diff for file.", vim.log.levels.INFO)
            return
        end

        local lines = {}
        for _, line in ipairs(diff_lines) do
            table.insert(lines, INLINE_PREFIX .. line)
        end

        if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
            vim.api.nvim_set_option_value("modifiable", true, { buf = M.buf })
            vim.api.nvim_buf_set_lines(M.buf, line_nr, line_nr, false, lines)
            vim.api.nvim_set_option_value("modifiable", false, { buf = M.buf })
        end
    end)
end

--- Toggle inline diff for a file
--- @param line_nr number The line number of the file entry
--- @param filename string The file to diff
--- @param state string The state of the file
--- @return nil
local function inline_diff_toggle(line_nr, filename, state)
    local next_line = vim.api.nvim_buf_get_lines(M.buf, line_nr, line_nr + 1, false)[1]
    if next_line and is_inline_diff_line(next_line) then
        inline_diff_remove(line_nr)
    else
        inline_diff_insert(line_nr, filename, state)
    end
end

--- Helper to execute multiple commands sequentially via exec_async
--- @param cmds table List of commands to execute
--- @param callback function|nil Optional callback when all are done
local function run_commands_async(cmds, callback)
    if #cmds == 0 then
        if callback then
            callback()
        end
        return
    end

    local function run_next(index)
        if index > #cmds then
            if callback then
                callback()
            end
            return
        end
        api.exec_async(cmds[index], nil, function()
            run_next(index + 1)
        end)
    end

    run_next(1)
end

--- Perform an action on the file under the cursor
--- @param action_type string The action to perform
--- @return nil
local function file_action(action_type)
    local filename, state, file_line = get_file_under_cursor()

    -- If no file under cursor, check if it's a section header
    if not filename then
        local line_nr = vim.api.nvim_win_get_cursor(0)[1]
        local line = vim.api.nvim_get_current_line()
        if line:match("^[A-Za-z]+:$") then
            -- We are on a section header. Gather all files in this section.
            local lines = vim.api.nvim_buf_get_lines(M.buf, line_nr, -1, false)
            local files = {}
            for _, next_line in ipairs(lines) do
                if next_line == "" or next_line:match("^[A-Za-z]+:$") then
                    break -- End of section
                end
                local f, s = parse_file_line(next_line)
                if f then
                    table.insert(files, { filename = f, state = s })
                end
            end

            if #files == 0 then
                return
            end

            local commands_to_run = {}
            local applied_count = 0

            if action_type == "stage" then
                local to_add = {}
                local to_rm = {}
                for _, f in ipairs(files) do
                    if f.state == "UNTRACKED" then
                        table.insert(to_add, f.filename)
                    elseif f.state == "MISSING" then
                        table.insert(to_rm, f.filename)
                    end
                end
                if #to_add > 0 then
                    local cmd = { "add" }
                    for _, file in ipairs(to_add) do
                        table.insert(cmd, file)
                    end
                    table.insert(commands_to_run, cmd)
                    applied_count = applied_count + #to_add
                end
                if #to_rm > 0 then
                    local cmd = { "rm" }
                    for _, file in ipairs(to_rm) do
                        table.insert(cmd, file)
                    end
                    table.insert(commands_to_run, cmd)
                    applied_count = applied_count + #to_rm
                end
            elseif action_type == "unstage" then
                local to_rm_soft = {}
                local to_revert = {}
                for _, f in ipairs(files) do
                    if f.state == "ADDED" then
                        table.insert(to_rm_soft, f.filename)
                    elseif f.state == "DELETED" then
                        table.insert(to_revert, f.filename)
                    end
                end
                if #to_rm_soft > 0 then
                    local cmd = { "rm", "--soft" }
                    for _, file in ipairs(to_rm_soft) do
                        table.insert(cmd, file)
                    end
                    table.insert(commands_to_run, cmd)
                    applied_count = applied_count + #to_rm_soft
                end
                if #to_revert > 0 then
                    local cmd = { "revert" }
                    for _, file in ipairs(to_revert) do
                        table.insert(cmd, file)
                    end
                    table.insert(commands_to_run, cmd)
                    applied_count = applied_count + #to_revert
                end
            elseif action_type == "toggle" then
                local to_add = {}
                local to_rm_soft = {}
                local to_rm = {}
                local to_revert = {}
                for _, f in ipairs(files) do
                    if f.state == "UNTRACKED" then
                        table.insert(to_add, f.filename)
                    elseif f.state == "ADDED" then
                        table.insert(to_rm_soft, f.filename)
                    elseif f.state == "MISSING" then
                        table.insert(to_rm, f.filename)
                    elseif f.state == "DELETED" then
                        table.insert(to_revert, f.filename)
                    end
                end
                if #to_add > 0 then
                    local cmd = { "add" }
                    for _, file in ipairs(to_add) do
                        table.insert(cmd, file)
                    end
                    table.insert(commands_to_run, cmd)
                    applied_count = applied_count + #to_add
                end
                if #to_rm_soft > 0 then
                    local cmd = { "rm", "--soft" }
                    for _, file in ipairs(to_rm_soft) do
                        table.insert(cmd, file)
                    end
                    table.insert(commands_to_run, cmd)
                    applied_count = applied_count + #to_rm_soft
                end
                if #to_rm > 0 then
                    local cmd = { "rm" }
                    for _, file in ipairs(to_rm) do
                        table.insert(cmd, file)
                    end
                    table.insert(commands_to_run, cmd)
                    applied_count = applied_count + #to_rm
                end
                if #to_revert > 0 then
                    local cmd = { "revert" }
                    for _, file in ipairs(to_revert) do
                        table.insert(cmd, file)
                    end
                    table.insert(commands_to_run, cmd)
                    applied_count = applied_count + #to_revert
                end
            elseif action_type == "discard" then
                local to_clean = {}
                local to_rm = {}
                local to_revert = {}
                for _, f in ipairs(files) do
                    if f.state == "UNTRACKED" then
                        table.insert(to_clean, f.filename)
                    elseif f.state == "ADDED" then
                        table.insert(to_rm, f.filename)
                    else
                        table.insert(to_revert, f.filename)
                    end
                end
                if #to_clean > 0 then
                    local cmd = { "clean", "--force" }
                    for _, file in ipairs(to_clean) do
                        table.insert(cmd, file)
                    end
                    table.insert(commands_to_run, cmd)
                    applied_count = applied_count + #to_clean
                end
                if #to_rm > 0 then
                    local cmd = { "rm" }
                    for _, file in ipairs(to_rm) do
                        table.insert(cmd, file)
                    end
                    table.insert(commands_to_run, cmd)
                    applied_count = applied_count + #to_rm
                end
                if #to_revert > 0 then
                    local cmd = { "revert" }
                    for _, file in ipairs(to_revert) do
                        table.insert(cmd, file)
                    end
                    table.insert(commands_to_run, cmd)
                    applied_count = applied_count + #to_revert
                end
            end

            if #commands_to_run > 0 then
                run_commands_async(commands_to_run, function()
                    M.refresh()
                    vim.notify(
                        "Applied action '" .. action_type .. "' to " .. applied_count .. " files.",
                        vim.log.levels.INFO
                    )
                end)
            else
                vim.notify("No valid files for action '" .. action_type .. "'.", vim.log.levels.INFO)
            end
            return
        end
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
            api.exec_async({ "add", filename }, nil, function() M.refresh() end)
        elseif state == "MISSING" then
            api.exec_async({ "rm", filename }, nil, function() M.refresh() end)
        elseif state == "ADDED" or state == "DELETED" then
            vim.notify("Already added/staged.", vim.log.levels.INFO)
        else
            vim.notify("Fossil has no staging for tracked files.", vim.log.levels.INFO)
        end
    elseif action_type == "unstage" then
        if state == "ADDED" then
            api.exec_async({ "rm", "--soft", filename }, nil, function() M.refresh() end)
        elseif state == "DELETED" then
            api.exec_async({ "revert", filename }, nil, function() M.refresh() end)
        elseif state == "UNTRACKED" then
            vim.notify("File is untracked.", vim.log.levels.INFO)
        else
            vim.notify("Nothing to unstage. Use X to discard changes.", vim.log.levels.INFO)
        end
    elseif action_type == "toggle" then
        if state == "UNTRACKED" then
            api.exec_async({ "add", filename }, nil, function() M.refresh() end)
        elseif state == "ADDED" then
            api.exec_async({ "rm", "--soft", filename }, nil, function() M.refresh() end)
        elseif state == "MISSING" then
            api.exec_async({ "rm", filename }, nil, function() M.refresh() end)
        elseif state == "DELETED" then
            api.exec_async({ "revert", filename }, nil, function() M.refresh() end)
        else
            vim.notify("Fossil has no staging for tracked files.", vim.log.levels.INFO)
        end
    elseif action_type == "discard" then
        if state == "UNTRACKED" then
            api.exec_async({ "clean", "--force", filename }, nil, function() M.refresh() end)
        elseif state == "ADDED" then
            api.exec_async({ "rm", filename }, nil, function() M.refresh() end)
        else
            api.exec_async({ "revert", filename }, nil, function() M.refresh() end)
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

--- Select and apply/pop a stash
--- @param action string The stash action ("apply" or "pop")
--- @return nil
local function select_stash(action)
    local output = api.exec({ "stash", "ls" })
    if #output == 0 or (#output == 1 and output[1] == "empty stash") then
        vim.notify("No stashes found.", vim.log.levels.INFO)
        return
    end

    local stashes = {}
    local current_stash = nil

    for _, line in ipairs(output) do
        local id, commit, date = line:match("^%s*(%d+):%s+%[(.-)%]%s+on%s+(.*)$")
        if id then
            if current_stash then
                table.insert(stashes, current_stash)
            end
            current_stash = {
                id = id,
                commit = commit,
                date = date,
                comment = "",
            }
        elseif current_stash then
            -- Append to comment
            local comment_line = line:match("^%s*(.*)$")
            if comment_line and comment_line ~= "" then
                if current_stash.comment == "" then
                    current_stash.comment = comment_line
                else
                    current_stash.comment = current_stash.comment .. " " .. comment_line
                end
            end
        end
    end
    if current_stash then
        table.insert(stashes, current_stash)
    end

    if #stashes == 0 then
        vim.notify("No stashes found.", vim.log.levels.INFO)
        return
    end

    vim.ui.select(stashes, {
        prompt = "Select stash to " .. action .. ":",
        format_item = function(item)
            local display = string.format("%s: [%s] %s", item.id, item.commit, item.date)
            if item.comment ~= "" then
                display = display .. " - " .. item.comment
            end
            return display
        end,
    }, function(choice)
        if choice then
            api.exec({ "stash", action, choice.id })
            M.refresh()
            vim.notify(
                string.format("%s stash %s.", action == "pop" and "Popped" or "Applied", choice.id),
                vim.log.levels.INFO
            )
        end
    end)
end

--- Refresh the status buffer
--- @return nil
function M.refresh()
    if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
        return
    end
    vim.api.nvim_set_option_value("modifiable", true, { buf = M.buf })
    vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, { "Loading..." })
    vim.api.nvim_set_option_value("modifiable", false, { buf = M.buf })

    get_status_lines_async(function(lines)
        if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
            return
        end
        vim.api.nvim_set_option_value("modifiable", true, { buf = M.buf })
        vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
        vim.api.nvim_set_option_value("modifiable", false, { buf = M.buf })
    end)
end

--- Open the status window
--- @return nil
function M.open_status_window()
    -- Check if already open
    if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
        local win = vim.fn.bufwinnr(M.buf)
        if win ~= -1 then
            vim.cmd(win .. "wincmd w")
            M.refresh()
            return
        else
            -- Buffer exists but is hidden, split and switch to it
            vim.cmd("botright sbuffer " .. M.buf)
            M.refresh()
            return
        end
    end

    -- If M.buf got lost but the buffer actually still exists by name, find it
    local existing_bufnr = vim.fn.bufnr("^Fossil Status$")
    if existing_bufnr ~= -1 and vim.api.nvim_buf_is_valid(existing_bufnr) then
        M.buf = existing_bufnr
        local win = vim.fn.bufwinnr(M.buf)
        if win ~= -1 then
            vim.cmd(win .. "wincmd w")
        else
            vim.cmd("botright sbuffer " .. M.buf)
        end
        M.refresh()
        return
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

    -- Auto-refresh autocommands
    local augroup = vim.api.nvim_create_augroup("FossilStatusAutoRefresh", { clear = true })
    vim.api.nvim_create_autocmd({ "BufWritePost", "FocusGained", "ShellCmdPost" }, {
        group = augroup,
        callback = function()
            if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
                M.refresh()
            end
        end,
    })
    vim.api.nvim_create_autocmd("BufEnter", {
        group = augroup,
        buffer = M.buf,
        callback = function()
            if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
                M.refresh()
            end
        end,
    })

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
    vim.keymap.set("n", "dq", function()
        vim.cmd("only | diffoff!")
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
    vim.keymap.set("n", "]/", function()
        jump_to_file(1)
    end, opts)
    vim.keymap.set("n", "[/", function()
        jump_to_file(-1)
    end, opts)
    vim.keymap.set("n", "]c", function()
        vim.fn.search("^    @@", "W")
    end, opts)
    vim.keymap.set("n", "[c", function()
        vim.fn.search("^    @@", "bW")
    end, opts)
    vim.keymap.set("n", "gu", function()
        jump_to_section("^Untracked:")
    end, opts)
    vim.keymap.set("n", "gU", function()
        jump_to_section("^Changes:")
    end, opts)
    vim.keymap.set("n", "gs", function()
        jump_to_section("^Changes:")
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
    vim.keymap.set("n", "U", function()
        unstage_all()
    end, opts)
    vim.keymap.set("n", "X", function()
        file_action("discard")
    end, opts)

    -- Commit (cc) & Log (cl) & Stash (czz)
    vim.keymap.set("n", "cc", function()
        require("fossil.command").execute({ "commit" })
    end, opts)
    vim.keymap.set("n", "cl", function()
        require("fossil.command").execute({ "clog" })
    end, opts)
    vim.keymap.set("n", "czz", function()
        vim.ui.input({ prompt = "Stash comment: " }, function(input)
            if input ~= nil then
                require("fossil.api").exec({ "stash", "save", "-m", input })
                M.refresh()
                vim.notify("Stashed changes.", vim.log.levels.INFO)
            end
        end)
    end, opts)
    vim.keymap.set("n", "czA", function()
        require("fossil.api").exec({ "stash", "apply" })
        M.refresh()
        vim.notify("Applied stash.", vim.log.levels.INFO)
    end, opts)
    vim.keymap.set("n", "cza", function()
        select_stash("apply")
    end, opts)
    vim.keymap.set("n", "czP", function()
        require("fossil.api").exec({ "stash", "pop" })
        M.refresh()
        vim.notify("Popped stash.", vim.log.levels.INFO)
    end, opts)
    vim.keymap.set("n", "czp", function()
        select_stash("pop")
    end, opts)

    -- Command line populating mappings
    local feedkeys = vim.api.nvim_feedkeys
    local termcodes = vim.api.nvim_replace_termcodes
    local function feed(keys)
        feedkeys(termcodes(keys, true, false, true), "n", false)
    end

    vim.keymap.set("n", "c<Space>", function()
        feed(":F commit ")
    end, opts)
    vim.keymap.set("n", "cb<Space>", function()
        feed(":F branch ")
    end, opts)
    vim.keymap.set("n", "co<Space>", function()
        feed(":F checkout ")
    end, opts)
    vim.keymap.set("n", "cr<Space>", function()
        feed(":F revert ")
    end, opts)
    vim.keymap.set("n", "cm<Space>", function()
        feed(":F merge ")
    end, opts)
    vim.keymap.set("n", "cz<Space>", function()
        feed(":F stash ")
    end, opts)

    vim.keymap.set("n", ".", function()
        local filename = get_file_under_cursor()
        if filename then
            feed(":F " .. filename .. "<C-B><C-Right><Right> ")
        end
    end, opts)

    -- Help
    vim.keymap.set("n", "g?", function()
        vim.cmd("help fossil-mappings")
    end, opts)

    -- Quit
    vim.keymap.set("n", "q", "<cmd>q<cr>", opts)
    vim.keymap.set("n", "gq", "<cmd>q<cr>", opts)
end

return M
