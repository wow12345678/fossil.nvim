local api = require("fossil.api")
local status = require("fossil.ui.status")

describe("status filename arguments", function()
    local original_async, original_exec, original_cwd, original_home
    local calls, state, tmp

    local function invoke(lhs)
        for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
            if map.lhs == lhs then
                map.callback()
                return
            end
        end
        error("Missing mapping: " .. lhs)
    end

    local function select_line(text)
        for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
            if line:find(text, 1, true) then
                vim.api.nvim_win_set_cursor(0, { i, 0 })
                return true
            end
        end
        return false
    end

    before_each(function()
        calls, state = {}, "UNTRACKED"
        original_async, original_exec = api.exec_async, api.exec
        original_cwd, original_home = vim.fn.getcwd(), vim.env.FOSSIL_HOME
        api.exec_async = function(args, _, callback)
            table.insert(calls, args)
            if args[1] == "status" then
                local lines = { "tags: trunk" }
                if state ~= "UNTRACKED" then
                    table.insert(lines, state .. "     --verily")
                end
                callback(lines, 0)
            elseif args[1] == "extras" then
                callback(state == "UNTRACKED" and { "--verily" } or {}, 0)
            else
                callback({}, 0)
            end
        end
    end)

    after_each(function()
        pcall(vim.api.nvim_clear_autocmds, { group = "FossilStatusAutoRefresh" })
        if status.buf and vim.api.nvim_buf_is_valid(status.buf) then
            vim.api.nvim_buf_delete(status.buf, { force = true })
        end
        status.buf = nil
        api.exec_async, api.exec = original_async, original_exec
        vim.cmd.cd(original_cwd)
        vim.env.FOSSIL_HOME = original_home
        if tmp then
            vim.fn.delete(tmp, "rf")
            tmp = nil
        end
    end)

    for _, case in ipairs({
        { "UNTRACKED", "s", { "add", "--", "--verily" } },
        { "UNTRACKED", "-", { "add", "--", "--verily" } },
        { "UNTRACKED", "X", { "clean", "--force", "--", "--verily" } },
        { "ADDED", "u", { "rm", "--soft", "--", "--verily" } },
        { "ADDED", "-", { "rm", "--soft", "--", "--verily" } },
        { "ADDED", "X", { "rm", "--", "--verily" } },
        { "MISSING", "s", { "rm", "--", "--verily" } },
        { "MISSING", "-", { "rm", "--", "--verily" } },
        { "DELETED", "u", { "revert", "--", "--verily" } },
        { "DELETED", "-", { "revert", "--", "--verily" } },
        { "EDITED", "X", { "revert", "--", "--verily" } },
        { "EDITED", "=", { "diff", "--unified", "--", "--verily" } },
    }) do
        for _, section in ipairs({ false, true }) do
            if not section or case[2] ~= "=" then
                it("delimits " .. case[1] .. " " .. case[2] .. (section and " section" or " file"), function()
                    state = case[1]
                    status.open_status_window()
                    assert.is_true(
                        select_line(section and (state == "UNTRACKED" and "Untracked:" or "Changes:") or "--verily")
                    )
                    calls = {}
                    invoke(case[2])
                    assert.are.same(case[3], calls[1])
                end)
            end
        end
    end

    it("keeps unrelated files when discarding a real file named --verily", function()
        tmp = vim.fn.tempname()
        vim.fn.mkdir(tmp .. "/checkout", "p")
        vim.fn.mkdir(tmp .. "/home", "p")
        vim.env.FOSSIL_HOME = tmp .. "/home"
        local function fossil(args)
            local cmd = { "fossil" }
            vim.list_extend(cmd, args)
            local result = vim.system(cmd, { cwd = tmp .. "/checkout", text = true }):wait()
            assert.are.equal(0, result.code, result.stderr)
        end
        fossil({ "init", tmp .. "/repo.fossil" })
        fossil({ "open", tmp .. "/repo.fossil" })
        vim.fn.writefile({ "selected" }, tmp .. "/checkout/--verily")
        vim.fn.writefile({ "keep me" }, tmp .. "/checkout/unrelated.txt")
        vim.cmd.cd(tmp .. "/checkout")
        api.exec_async = original_async
        status.open_status_window()
        assert.is_true(vim.wait(3000, function()
            return select_line("--verily")
        end))
        invoke("X")
        assert.is_true(vim.wait(3000, function()
            return vim.fn.filereadable("--verily") == 0
        end))
        assert.are.same({ "keep me" }, vim.fn.readfile("unrelated.txt"))
        -- Wait for the action's asynchronous refresh before tearing down the checkout.
        assert.is_true(vim.wait(3000, function()
            return select_line("unrelated.txt") and not select_line("--verily")
        end))
    end)
end)
