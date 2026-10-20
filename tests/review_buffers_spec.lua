local api = require("fossil.api")
local blame = require("fossil.ui.blame")
local finfo = require("fossil.ui.finfo")

describe("review buffers", function()
    local original_exec, source, path, tmp

    local function invoke(lhs)
        for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
            if map.lhs == lhs then
                map.callback()
                return
            end
        end
        error("Missing mapping: " .. lhs)
    end

    local function select_hash(hash)
        for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
            if line:find("[" .. hash .. "]", 1, true) then
                vim.api.nvim_win_set_cursor(0, { i, 0 })
                return
            end
        end
        error("Missing history entry")
    end

    local function assert_source()
        assert.is_true(vim.api.nvim_buf_is_valid(source))
        assert.are.equal(path, vim.api.nvim_buf_get_name(source))
        assert.are.same({ "unsaved working copy" }, vim.api.nvim_buf_get_lines(source, 0, -1, false))
        assert.are.equal("", vim.bo[source].buftype)
        assert.is_true(vim.bo[source].modified)
        assert.is_true(vim.bo[source].modifiable)
    end

    before_each(function()
        original_exec = api.exec
        tmp = vim.fn.tempname()
        vim.fn.mkdir(tmp, "p")
        path = tmp .. "/source.txt"
        vim.fn.writefile({ "saved working copy" }, path)
        vim.cmd.edit(path)
        source = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(source, 0, -1, false, { "unsaved working copy" })
        api.exec = function(args)
            if args[1] == "blame" then
                return { "aaaa1111 author: saved working copy" }, 0
            elseif args[1] == "finfo" then
                return { "2026-01-02 [aaaa1111] newer", "2026-01-01 [bbbb2222] older" }, 0
            elseif args[1] == "cat" then
                return { args[4] == "aaaa1111" and "newer contents" or "older contents" }, 0
            end
            return {}, 0
        end
    end)

    after_each(function()
        api.exec = original_exec
        vim.cmd("silent! %bwipeout!")
        vim.fn.delete(tmp, "rf")
    end)

    it("keeps unsaved source contents when opening and closing blame", function()
        blame.open_blame_view({ "blame", path })
        assert_source()
        local review
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == "fossilblame" then
                review = buf
            end
        end
        assert.is_not_nil(review)
        assert.are_not.equal(source, review)
        vim.api.nvim_buf_delete(review, { force = true })
        assert_source()
    end)

    it("uses a distinct buffer for a historical-versus-working-copy diff", function()
        finfo.open_finfo_window({ "finfo", path })
        select_hash("aaaa1111")
        invoke("d")
        local review = vim.api.nvim_get_current_buf()
        assert.are_not.equal(source, review)
        assert.are.same({ "newer contents" }, vim.api.nvim_buf_get_lines(review, 0, -1, false))
        assert_source()
        vim.api.nvim_buf_delete(review, { force = true })
        assert_source()
    end)

    for _, mode in ipairs({ "D", "M" }) do
        it("shows two independent historical buffers with " .. mode, function()
            finfo.open_finfo_window({ "finfo", path })
            select_hash("aaaa1111")
            if mode == "M" then
                invoke("m")
                select_hash("bbbb2222")
            end
            invoke(mode)
            local buffers, contents = {}, {}
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                local buf = vim.api.nvim_win_get_buf(win)
                assert.is_nil(buffers[buf])
                buffers[buf] = true
                assert.are_not.equal(source, buf)
                assert.is_false(vim.bo[buf].modifiable)
                table.insert(contents, vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1])
            end
            table.sort(contents)
            assert.are.same({ "newer contents", "older contents" }, contents)
            assert_source()
        end)
    end
end)
