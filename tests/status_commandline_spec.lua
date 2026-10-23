local api = require("fossil.api")
local status = require("fossil.ui.status")

vim.cmd("runtime plugin/fossil.lua")

describe("status command-line filenames", function()
    local original_async
    local original_exec
    local dispatched
    local filename

    before_each(function()
        original_async = api.exec_async
        original_exec = api.exec
        dispatched = {}
        api.exec = function(args)
            table.insert(dispatched, vim.deepcopy(args))
            return {}, 0
        end
        api.exec_async = function(args, _, callback)
            if args[1] == "status" then
                callback({ "tags: trunk" }, 0)
            elseif args[1] == "extras" then
                callback({ filename }, 0)
            else
                callback({}, 0)
            end
        end
        vim.g.fossil_filename_executed = nil
    end)

    after_each(function()
        api.exec_async = original_async
        api.exec = original_exec
        pcall(vim.api.nvim_clear_autocmds, { group = "FossilStatusAutoRefresh" })
        if status.buf and vim.api.nvim_buf_is_valid(status.buf) then
            vim.api.nvim_buf_delete(status.buf, { force = true })
        end
        status.buf = nil
        vim.g.fossil_filename_executed = nil
    end)

    local function populate(name, keys)
        filename = name
        status.open_status_window()
        vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(0), 0 })
        local observed
        vim.api.nvim_create_autocmd("CmdlineLeave", {
            pattern = ":",
            once = true,
            callback = function()
                observed = { text = vim.fn.getcmdline(), pos = vim.fn.getcmdpos() }
            end,
        })
        for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
            if map.lhs == "." then
                map.callback()
                break
            end
        end
        -- Process actual keys, either cancelling or submitting the command line.
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys or "<C-C>", true, false, true), "nx", false)
        return observed
    end

    it("does not execute key notation contained in a filename", function()
        local name = "evil<C-U>let g:fossil_filename_executed=1<CR>"
        local observed = populate(name)
        assert.is_nil(vim.g.fossil_filename_executed)
        assert.are.same({ text = "F  evil<C-U>let\\ g:fossil_filename_executed=1<CR>", pos = 3 }, observed)
    end)

    it("preserves special characters and leaves room to type a subcommand", function()
        local name = "notes <CR> % # |.txt"
        local observed = populate(name)
        assert.are.same({ text = "F  notes\\ <CR>\\ %\\ #\\ |.txt", pos = 3 }, observed)
    end)

    for _, name in ipairs({
        "a%b.txt",
        "a#b.txt",
        "a[b].txt",
        "a|b.txt",
        "notes <CR> % # |.txt",
        [[a\b\ c.txt]],
        "a\tb.txt",
        [[a'b"c.txt]],
        "evil<C-U>let g:fossil_filename_executed=1<CR>",
        "evil|let g:fossil_filename_executed=1",
    }) do
        it("dispatches the exact filename " .. vim.inspect(name), function()
            populate(name, "add<CR>")
            assert.is_nil(vim.g.fossil_filename_executed)
            assert.are.same({ { "add", name } }, dispatched)
        end)
    end
end)
