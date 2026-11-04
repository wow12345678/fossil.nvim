local conflict = {
    "start",
    "<<<<<<< BEGIN MERGE CONFLICT: local copy shown first <<<<<<<<<<<< (line 2)",
    "local",
    "=======",
    "####### SUGGESTED CONFLICT RESOLUTION follows ###################",
    "suggestion",
    "||||||| COMMON ANCESTOR content follows ||||||||||||||||||||||||| (line 2)",
    "ancestor",
    "======= MERGED IN content follows =============================== (line 2)",
    "incoming",
    ">>>>>>> END MERGE CONFLICT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>",
    "end",
}

local function assert_merge_panes(source)
    assert.are.equal(source, vim.api.nvim_get_current_win())
    assert.is_true(vim.api.nvim_get_option_value("diff", { win = source }))

    local panes = {}
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local buf = vim.api.nvim_win_get_buf(win)
        local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
        local side = name:match("^(%a+) %(MERGE %d+%)$")
        if side then
            assert.is_true(vim.api.nvim_get_option_value("diff", { win = win }))
            panes[side] = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        end
    end

    assert.are.same({ "start", "local", "=======", "end" }, panes.Local)
    assert.are.same({ "start", "incoming", "end" }, panes.Remote)
end

describe("Fossil conflict diff", function()
    local conflict_path

    after_each(function()
        vim.cmd("tabonly!")
        vim.cmd("only!")
        vim.cmd("enew!")
        if conflict_path then
            vim.fn.delete(conflict_path)
        end
    end)

    it("opens clean conflict panes through both shortcuts while an earlier view is open", function()
        vim.cmd("runtime plugin/fossil.lua")
        vim.cmd("tabnew")
        local first_source = vim.api.nvim_get_current_win()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, conflict)

        vim.cmd("vnew")
        local unrelated = vim.api.nvim_get_current_win()
        vim.api.nvim_set_current_win(first_source)
        vim.cmd("FDiffsplit!")
        assert_merge_panes(first_source)
        assert.is_false(vim.api.nvim_get_option_value("diff", { win = unrelated }))

        conflict_path = vim.fn.tempname() .. " conflict.txt"
        vim.fn.writefile(conflict, conflict_path)
        vim.cmd("tabnew")
        local second_source = vim.api.nvim_get_current_win()
        vim.cmd("FVdiffsplit! " .. vim.fn.fnameescape(conflict_path))
        assert.are.equal(conflict_path, vim.api.nvim_buf_get_name(0))
        assert_merge_panes(second_source)
        assert.is_true(vim.api.nvim_win_is_valid(first_source))
    end)
end)
