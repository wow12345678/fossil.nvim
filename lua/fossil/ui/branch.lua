local api = require("fossil.api")

local M = {}

--- Open a window to view and manage fossil branches
function M.open_branch_window()
    local output, code = api.exec({ "branch", "list" })
    if code ~= 0 then
        vim.notify("Failed to list branches.", vim.log.levels.ERROR)
        return
    end

    vim.cmd("botright new")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(buf, "Fossil Branches")

    -- Clean up output
    local lines = {
        "==================================================================",
        "|                    Fossil Branch Management                    |",
        "==================================================================",
        " <CR>  Checkout branch under cursor",
        " c     Create a new branch from current checkout",
        " d     Close branch under cursor",
        " m     Merge branch under cursor into current checkout",
        " q     Close this window",
        "==================================================================",
        "",
    }

    for _, line in ipairs(output) do
        table.insert(lines, line)
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- Set buffer options
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
    vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    vim.api.nvim_set_option_value("filetype", "fossilbranch", { buf = buf })

    -- Basic syntax highlighting
    local syntax_cmds = [[
		if exists("b:current_syntax")
		  finish
		endif

		syn match fossilBranchCurrent "^\*.*"
		syn match fossilBranchHeader "^====.*"
		syn match fossilBranchTitle "^|.*|$"
		syn match fossilBranchKey "^\s\+\S\+\s"

		hi def link fossilBranchCurrent String
		hi def link fossilBranchHeader Comment
		hi def link fossilBranchTitle Type
		hi def link fossilBranchKey Special

		let b:current_syntax = "fossilbranch"
	]]
    vim.cmd(syntax_cmds)

    local opts = { buffer = buf, silent = true, noremap = true }

    local function get_branch_under_cursor()
        local line = vim.api.nvim_get_current_line()
        if line:match("^=*") or line:match("^|") or line:match("^ <") or line:match("^ [a-z] ") or line == "" then
            return nil
        end
        -- fossil branch list outputs like:
        -- * trunk
        --   branch1
        --   branch2
        local branch = line:match("^%s*%*?%s*(.+)$")
        return branch
    end

    -- Checkout branch
    vim.keymap.set("n", "<CR>", function()
        local branch = get_branch_under_cursor()
        if not branch then
            return
        end
        require("fossil.operations").checkout({ "checkout", branch })
        -- refresh branch list
        vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
        local new_out, _ = api.exec({ "branch", "list" })
        local new_lines = {}
        for i = 1, 9 do
            table.insert(new_lines, lines[i])
        end
        for _, l in ipairs(new_out) do
            table.insert(new_lines, l)
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
        vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    end, opts)

    -- Create branch
    vim.keymap.set("n", "c", function()
        vim.ui.input({ prompt = "New branch name: " }, function(input)
            if input and input ~= "" then
                -- fossil branch new <name> <basis>
                local out, c = api.exec({ "branch", "new", input, "current" })
                if c == 0 then
                    vim.notify("Created branch " .. input, vim.log.levels.INFO)
                    -- refresh branch list
                    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
                    local new_out, _ = api.exec({ "branch", "list" })
                    local new_lines = {}
                    for i = 1, 9 do
                        table.insert(new_lines, lines[i])
                    end
                    for _, l in ipairs(new_out) do
                        table.insert(new_lines, l)
                    end
                    vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
                    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
                else
                    vim.notify("Failed to create branch:\n" .. table.concat(out, "\n"), vim.log.levels.ERROR)
                end
            end
        end)
    end, opts)

    -- Close branch
    vim.keymap.set("n", "d", function()
        local branch = get_branch_under_cursor()
        if not branch then
            return
        end

        -- Fossil doesn't "delete" branches, it closes them
        local confirm = vim.fn.confirm("Close branch '" .. branch .. "'? (y/N)", "&Yes\n&No", 2)
        if confirm == 1 then
            -- fossil commit --close is typically how you close a branch you are on, or you can use `fossil branch close` if it exists.
            -- Wait, fossil doesn't have `branch close` in all versions, usually you commit --close or add a tag.
            -- Let's use `fossil commit -m "Closed branch" --close` if it's the current branch,
            -- or `fossil tag add --raw closed <branch>`?
            -- Let's stick to closing a branch via `fossil branch close` or `fossil commit --close`.
            -- But wait, actually closing a branch in Fossil is done by checking it out and committing with --close, OR `fossil ammend --close <branch>`.
            -- `fossil amend --close <branch>` is the correct way without checking out.
            local out, c = api.exec({ "amend", "--close", branch })
            if c == 0 then
                vim.notify("Closed branch " .. branch, vim.log.levels.INFO)
                -- refresh branch list
                vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
                local new_out, _ = api.exec({ "branch", "list" })
                local new_lines = {}
                for i = 1, 10 do
                    table.insert(new_lines, lines[i])
                end
                for _, l in ipairs(new_out) do
                    table.insert(new_lines, l)
                end
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
                vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
            else
                vim.notify("Failed to close branch:\n" .. table.concat(out, "\n"), vim.log.levels.ERROR)
            end
        end
    end, opts)

    -- Merge branch
    vim.keymap.set("n", "m", function()
        local branch = get_branch_under_cursor()
        if not branch then
            return
        end

        local confirm = vim.fn.confirm("Merge branch '" .. branch .. "' into current checkout? (y/N)", "&Yes\n&No", 2)
        if confirm == 1 then
            local out, c = api.exec({ "merge", branch })
            if c == 0 then
                vim.notify("Merged branch " .. branch .. ":\n" .. table.concat(out, "\n"), vim.log.levels.INFO)
                vim.cmd("checktime")
                local has_status, status_mod = pcall(require, "fossil.ui.status")
                if has_status and status_mod.refresh then
                    status_mod.refresh()
                end
            else
                vim.notify("Merge failed or conflicts occurred:\n" .. table.concat(out, "\n"), vim.log.levels.WARN)
                vim.cmd("checktime")
                local has_status, status_mod = pcall(require, "fossil.ui.status")
                if has_status and status_mod.refresh then
                    status_mod.refresh()
                end
            end
        end
    end, opts)

    -- Quit
    vim.keymap.set("n", "q", "<cmd>q<cr>", opts)
end

return M
