local api = require("fossil.api")
local ops = require("fossil.operations")

describe("reading committed contents", function()
    local original_exec, tmp, path

    before_each(function()
        original_exec = api.exec
        tmp = vim.fn.tempname()
        vim.fn.mkdir(tmp, "p")
        path = tmp .. "/file.txt"
        vim.fn.writefile({ "working copy on disk" }, path)
        vim.cmd.edit(path)
        api.exec = function()
            return { "committed contents" }, 0
        end
    end)

    after_each(function()
        api.exec = original_exec
        vim.cmd("silent! %bwipeout!")
        vim.fn.delete(tmp, "rf")
    end)

    it("keeps restored contents modified until :update writes them", function()
        ops.read({ "read" })
        assert.are.same({ "committed contents" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
        assert.is_true(vim.bo.modified)
        assert.are.same({ "working copy on disk" }, vim.fn.readfile(path))
        vim.cmd.update()
        assert.are.same({ "committed contents" }, vim.fn.readfile(path))
        assert.is_false(vim.bo.modified)
    end)

    it("continues to protect unsaved edits without force", function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved edit" })
        ops.read({ "read" })
        assert.are.same({ "unsaved edit" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
        assert.is_true(vim.bo.modified)
    end)

    it("preserves the buffer and its saved state when fossil cat fails", function()
        api.exec = function()
            return { "missing file" }, 1
        end
        ops.read({ "read" })
        assert.are.same({ "working copy on disk" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
        assert.is_false(vim.bo.modified)
    end)
end)
