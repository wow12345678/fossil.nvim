vim.opt.rtp:prepend(vim.fn.getcwd())
local status = require("fossil.ui.status")

describe("inline hunk revert", function()
    local tmp, original_cwd, original_home, original_notify

    before_each(function()
        tmp = vim.fn.tempname()
        original_cwd, original_home, original_notify = vim.fn.getcwd(), vim.env.FOSSIL_HOME, vim.notify
        vim.fn.mkdir(tmp .. "/checkout", "p")
        vim.fn.mkdir(tmp .. "/home", "p")
        vim.env.FOSSIL_HOME = tmp .. "/home"
    end)

    after_each(function()
        pcall(vim.api.nvim_clear_autocmds, { group = "FossilStatusAutoRefresh" })
        if status.buf and vim.api.nvim_buf_is_valid(status.buf) then
            vim.api.nvim_buf_delete(status.buf, { force = true })
        end
        status.buf = nil
        vim.cmd.cd(original_cwd)
        vim.env.FOSSIL_HOME, vim.notify = original_home, original_notify
        vim.fn.delete(tmp, "rf")
    end)

    local function select_line(match)
        for row, line in ipairs(vim.api.nvim_buf_get_lines(status.buf, 0, -1, false)) do
            if match(line) then
                vim.api.nvim_win_set_cursor(0, { row, 0 })
                return true
            end
        end
        return false
    end

    local function check_revert(dir, filename, sibling_names)
        local root = tmp .. "/checkout"
        local cwd = root .. dir
        local file = cwd .. "/" .. filename

        local function fossil(args)
            local cmd = vim.list_extend({ "fossil" }, args)
            local result = vim.system(cmd, { cwd = root, text = true }):wait()
            assert.are.equal(0, result.code, result.stderr)
        end

        fossil({ "init", tmp .. "/repo.fossil" })
        fossil({ "open", tmp .. "/repo.fossil" })
        fossil({ "settings", "relative-paths", "off" })
        vim.fn.mkdir(cwd, "p")
        local base = {}
        for i = 1, 24 do
            base[i] = "original line " .. i
        end
        vim.fn.writefile(base, file)
        fossil({ "add", "." .. dir .. "/" .. filename })
        fossil({ "commit", "-m", "Add test file" })

        local edited = vim.deepcopy(base)
        edited[1], edited[24] = "first edit", "second edit"
        vim.fn.writefile(edited, file)
        for _, sibling in ipairs(sibling_names) do
            vim.fn.writefile(edited, root .. "/" .. sibling)
        end

        local result
        vim.notify = function(message)
            if message:match("^Reverted hunk") or message:match("^Failed to") then
                result = message
            end
        end
        vim.cmd.cd(cwd)
        status.open_status_window()
        assert.is_true(vim.wait(3000, function()
            return select_line(function(line)
                return line:match("^  EDITED") and vim.endswith(line, filename)
            end)
        end))
        vim.fn.maparg("=", "n", false, true).callback()
        assert.is_true(vim.wait(3000, function()
            return select_line(function(line)
                return line:match("^    @@")
            end)
        end))
        vim.fn.maparg("X", "n", false, true).callback()
        assert.is_true(vim.wait(3000, function()
            return result ~= nil
        end))
        assert.are.equal("Reverted hunk in " .. filename, result)
        for _, sibling in ipairs(sibling_names) do
            assert.are.same(edited, vim.fn.readfile(root .. "/" .. sibling))
        end
        edited[1] = base[1]
        assert.are.same(edited, vim.fn.readfile(file))
        assert.is_true(vim.wait(3000, function()
            return select_line(function(line)
                return line == "    +second edit"
            end)
        end))
    end

    it("reverts only the chosen hunk in a name with spaces", function()
        check_revert("", "space name.txt", { "space" })
    end)

    it("uses the status directory and preserves leading whitespace", function()
        check_revert("/sub", " space name.txt", { "space name.txt", "sub/space name.txt" })
    end)
end)
