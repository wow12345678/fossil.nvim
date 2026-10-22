local api = require("fossil.api")
local ops = require("fossil.operations")
local branch = require("fossil.ui.branch")
local wiki = require("fossil.ui.wiki")

describe("branch and wiki selections", function()
    local original_exec, original_checkout, original_confirm, calls

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
                return
            end
        end
        error("Missing entry")
    end

    before_each(function()
        calls = {}
        original_exec, original_checkout, original_confirm = api.exec, ops.checkout, vim.fn.confirm
        api.exec = function(args)
            table.insert(calls, args)
            if args[1] == "branch" then
                return { "* trunk", "  feature" }, 0
            elseif args[1] == "wiki" and args[2] == "ls" then
                return { "Home Page" }, 0
            elseif args[1] == "wiki" and args[2] == "export" then
                return { "existing wiki contents" }, 0
            end
            return {}, 0
        end
        ops.checkout = function(args)
            table.insert(calls, args)
        end
        vim.fn.confirm = function()
            return 1
        end
    end)

    after_each(function()
        api.exec, ops.checkout, vim.fn.confirm = original_exec, original_checkout, original_confirm
        vim.cmd("silent! %bwipeout!")
    end)

    for _, case in ipairs({
        { "<CR>", { "checkout", "feature" } },
        { "d", { "amend", "--close", "feature" } },
        { "m", { "merge", "feature" } },
    }) do
        it("dispatches branch " .. case[1] .. " for the selected row", function()
            branch.open_branch_window()
            select_line("  feature")
            calls = {}
            invoke(case[1])
            assert.are.same(case[2], calls[1])
        end)
    end

    it("opens an existing wiki page by selecting it", function()
        wiki.open_wiki_window()
        select_line("  Home Page")
        calls = {}
        invoke("<CR>")
        assert.are.same({ "wiki", "export", "Home Page" }, calls[1])
        assert.are.same({ "existing wiki contents" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
        assert.are.equal("acwrite", vim.bo.buftype)
    end)

    for _, view in ipairs({ branch.open_branch_window, wiki.open_wiki_window }) do
        it("ignores header, help and empty rows", function()
            view()
            local buf = vim.api.nvim_get_current_buf()
            calls = {}
            for row = 1, 8 do
                vim.api.nvim_win_set_cursor(0, { row, 0 })
                invoke("<CR>")
                assert.are.equal(buf, vim.api.nvim_get_current_buf())
            end
            assert.are.same({}, calls)
        end)
    end
end)
