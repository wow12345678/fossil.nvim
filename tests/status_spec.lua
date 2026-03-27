local status = require("fossil.ui.status")
local api = require("fossil.api")

describe("fossil.ui.status", function()
    it("refresh should safely return if no buffer is set", function()
        -- Should not error
        status.refresh()
    end)

    it("should parse status properly (mocked)", function()
        local original_exec = api.exec
        api.exec = function(args)
            if args[1] == "status" then
                return { "repository: /test", "local-root: /test/", "EDITED     file.txt" }, 0
            elseif args[1] == "extras" then
                return { "untracked.txt" }, 0
            end
            return {}, 0
        end

        status.open_status_window()

        -- verify buffer is created
        local buf = vim.api.nvim_get_current_buf()
        local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf })
        assert.are.same("fossil", filetype)

        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        -- "repository: /test", "local-root: /test/", "", "Changes:", "  EDITED     file.txt", "", "Untracked:", "  ? untracked.txt"
        assert.are.same("repository: /test", lines[1])
        assert.are.same("local-root: /test/", lines[2])
        assert.are.same("", lines[3])
        assert.are.same("Changes:", lines[4])
        assert.are.same("  EDITED     file.txt", lines[5])
        assert.are.same("", lines[6])
        assert.are.same("Untracked:", lines[7])
        assert.are.same("  ? untracked.txt", lines[8])

        api.exec = original_exec
    end)
end)
