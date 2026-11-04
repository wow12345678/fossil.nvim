local commit = require("fossil.ui.commit")

describe("commit checkout context", function()
    local tmp, original_cwd, original_home
    local function fossil(cwd, args)
        local cmd = { "fossil" }
        vim.list_extend(cmd, args)
        local result = vim.system(cmd, { cwd = cwd, text = true }):wait()
        assert.are.equal(0, result.code, result.stderr)
        return result.stdout
    end

    before_each(function()
        original_cwd, original_home = vim.fn.getcwd(), vim.env.FOSSIL_HOME
        tmp = vim.fn.tempname()
        vim.fn.mkdir(tmp .. "/home", "p")
        vim.env.FOSSIL_HOME = tmp .. "/home"
        for _, name in ipairs({ "a", "b" }) do
            local dir = tmp .. "/" .. name
            vim.fn.mkdir(dir, "p")
            fossil(dir, { "init", tmp .. "/" .. name .. ".fossil" })
            fossil(dir, { "open", tmp .. "/" .. name .. ".fossil" })
            fossil(dir, { "settings", "autosync", "off" })
            vim.fn.mkdir(dir .. "/sub", "p")
            vim.fn.writefile({ "initial " .. name }, dir .. "/sub/file.txt")
            fossil(dir, { "add", "sub/file.txt" })
            fossil(dir, { "commit", "-m", "initial" })
            vim.fn.writefile({ "changed working copy " .. name }, dir .. "/sub/file.txt")
        end
    end)

    after_each(function()
        vim.cmd("silent! %bwipeout!")
        vim.cmd.cd(original_cwd)
        vim.env.FOSSIL_HOME = original_home
        vim.fn.delete(tmp, "rf")
    end)

    it("commits the originating checkout after changing to another checkout", function()
        vim.cmd.cd(tmp .. "/a")
        commit.open_commit_buffer({ "commit" })
        vim.api.nvim_buf_set_lines(0, 0, 1, false, { "commit intended for A" })
        vim.cmd.cd(tmp .. "/b")
        vim.cmd.write()
        assert.are.equal("", fossil(tmp .. "/a", { "changes" }))
        assert.is_truthy(fossil(tmp .. "/a", { "timeline", "-n", "1" }):find("commit intended for A", 1, true))
        assert.is_truthy(fossil(tmp .. "/b", { "changes" }):find("file.txt", 1, true))
        assert.is_nil(fossil(tmp .. "/b", { "timeline", "-n", "1" }):find("commit intended for A", 1, true))
    end)

    it("preserves relative file arguments from the originating subdirectory", function()
        vim.cmd.cd(tmp .. "/a/sub")
        commit.open_commit_buffer({ "commit", "file.txt" })
        vim.api.nvim_buf_set_lines(0, 0, 1, false, { "subdirectory commit" })
        vim.cmd.cd(tmp .. "/b")
        vim.cmd.write()
        assert.are.equal("", fossil(tmp .. "/a", { "changes" }))
        assert.is_truthy(fossil(tmp .. "/b", { "changes" }):find("file.txt", 1, true))
    end)

    it("does not open a commit buffer outside a checkout", function()
        vim.cmd.cd(tmp)
        local before = vim.api.nvim_get_current_buf()
        commit.open_commit_buffer({ "commit" })
        assert.are.equal(before, vim.api.nvim_get_current_buf())
        assert.are_not.equal("fossilcommit", vim.bo.filetype)
    end)
end)
