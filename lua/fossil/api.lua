local M = {}

local function parse_output(output_str, output_table)
    if not output_str then return end
    local lines = vim.split(output_str, "\r?\n")
    if #lines > 0 and lines[#lines] == "" then
        table.remove(lines)
    end
    for _, line in ipairs(lines) do
        table.insert(output_table, line)
    end
end

--- Run a fossil command synchronously and return its output as a table of lines
--- @param args table: The arguments to pass to fossil (e.g. {"status"})
--- @param cwd string|nil: Optional working directory
--- @param opts table|nil: Optional settings like `{ quiet = true }`
--- @return table: List of lines from stdout/stderr
--- @return number: Exit code
function M.exec(args, cwd, opts)
    opts = opts or {}
    local cmd = { "fossil" }
    for _, arg in ipairs(args) do
        table.insert(cmd, arg)
    end

    local ok, obj = pcall(function()
        return vim.system(cmd, { text = true, cwd = cwd, timeout = 10000 }):wait()
    end)

    if not ok or not obj then
        local err_msg = "Failed to execute fossil command: " .. tostring(obj)
        if not opts.quiet then
            vim.notify(err_msg, vim.log.levels.ERROR)
        end
        return { err_msg }, -1
    end

    if (obj.code ~= 0 or (obj.signal and obj.signal ~= 0)) and not opts.quiet then
        local err_msg = "Fossil command failed with code " .. tostring(obj.code) .. " signal " .. tostring(obj.signal)
        if obj.stderr and obj.stderr ~= "" then
            err_msg = err_msg .. ": " .. obj.stderr
        end
        vim.notify(err_msg, vim.log.levels.ERROR)
    end

    local output = {}
    parse_output(obj.stdout, output)
    parse_output(obj.stderr, output)

    return output, obj.code
end

--- Run a fossil command asynchronously
--- @param args table: The arguments to pass to fossil
--- @param cwd string|nil: Optional working directory
--- @param callback function: Called on completion with (output_lines, exit_code)
--- @param opts table|nil: Optional settings like `{ quiet = true }`
function M.exec_async(args, cwd, callback, opts)
    opts = opts or {}
    local cmd = { "fossil" }
    for _, arg in ipairs(args) do
        table.insert(cmd, arg)
    end

    local ok, err = pcall(function()
        vim.system(cmd, { text = true, cwd = cwd, timeout = 10000 }, function(obj)
            if (obj.code ~= 0 or (obj.signal and obj.signal ~= 0)) and not opts.quiet then
                local err_msg = "Fossil command failed with code " .. tostring(obj.code) .. " signal " .. tostring(obj.signal)
                if obj.stderr and obj.stderr ~= "" then
                    err_msg = err_msg .. ": " .. obj.stderr
                end
                vim.schedule(function()
                    vim.notify(err_msg, vim.log.levels.ERROR)
                end)
            end

            local output = {}
            parse_output(obj.stdout, output)
            parse_output(obj.stderr, output)
            if callback then
                vim.schedule(function()
                    callback(output, obj.code)
                end)
            end
        end)
    end)

    if not ok and callback then
        local err_msg = "Failed to execute fossil command: " .. tostring(err)
        vim.schedule(function()
            if not opts.quiet then
                vim.notify(err_msg, vim.log.levels.ERROR)
            end
            callback({ err_msg }, -1)
        end)
    end
end

--- Check if the current directory or the given directory is inside a fossil checkout
--- @param dir string|nil
--- @return boolean
function M.is_checkout(dir)
    local _, code = M.exec({ "info" }, dir, { quiet = true })
    return code == 0
end

return M
