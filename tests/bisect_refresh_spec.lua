local api = require("fossil.api")
local bisect = require("fossil.ui.bisect")

describe("bisect refresh", function()
    local original_exec, logs, action

    local function invoke(lhs)
        for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
            if map.lhs == lhs then
                map.callback()
                return
            end
        end
        error("Missing mapping: " .. lhs)
    end

    before_each(function()
        original_exec = api.exec
        logs, action = 0, nil
        api.exec = function(args)
            if args[2] == "log" then
                logs = logs + 1
                return { "log " .. logs }, 0
            end
            action = args[2]
            return {}, 0
        end
    end)

    after_each(function()
        api.exec = original_exec
        vim.cmd("silent! %bwipeout!")
    end)

    it("updates the log on R and restores read-only behavior", function()
        bisect.open_bisect_window()
        assert.is_false(vim.bo.modifiable)
        invoke("R")
        assert.are.same({ "log 2" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
        assert.is_false(vim.bo.modifiable)
    end)

    for _, case in ipairs({ { "mg", "good" }, { "mb", "bad" }, { "ms", "skip" }, { "mr", "reset" } }) do
        it("refreshes after " .. case[2] .. " without leaving the buffer editable", function()
            bisect.open_bisect_window()
            invoke(case[1])
            assert.are.equal(case[2], action)
            assert.are.same({ "log 2" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
            assert.is_false(vim.bo.modifiable)
        end)
    end
end)
