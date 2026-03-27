local api = require("fossil.api")
local window = require("fossil.ui.window")

local M = {}

function M.open_stash_window()
    local output, code = api.exec({ "stash", "ls" })
    local content = output
    if #content == 0 or (#content == 1 and content[1] == "empty stash") then
        content = { "No stashes found." }
    end

    local buf = window.open_scratch_buffer("Fossil Stash", content)
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

    local function refresh()
        local new_out, new_code = api.exec({ "stash", "ls" })
        local new_content = new_out
        if #new_content == 0 or (#new_content == 1 and new_content[1] == "empty stash") then
            new_content = { "No stashes found." }
        end
        vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_content)
        vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    end

    local function get_stash_id_under_cursor()
        local line = vim.api.nvim_get_current_line()
        -- Stash format:  1: [00000000000000] on 2024-01-01 12:00:00
        local stash_id = string.match(line, "^%s*(%d+):")
        return stash_id
    end

    local function stash_action(action)
        return function()
            local id = get_stash_id_under_cursor()
            if not id then
                vim.notify("No stash ID found on the current line.", vim.log.levels.WARN)
                return
            end

            local args = { "stash", action, id }
            local out, c = api.exec(args)
            if c ~= 0 then
                vim.notify(
                    "Failed to " .. action .. " stash " .. id .. ":\n" .. table.concat(out, "\n"),
                    vim.log.levels.ERROR
                )
            else
                vim.notify("Stash " .. id .. " " .. action .. " successful.", vim.log.levels.INFO)
                vim.defer_fn(function()
                    vim.notify(
                        "Stash UI mappings: <CR>(diff), a(apply), p(pop), d(drop), R(refresh), q(quit)",
                        vim.log.levels.INFO
                    )
                end, 3000)
            end
            refresh()
        end
    end

    local function stash_diff()
        local id = get_stash_id_under_cursor()
        if not id then
            vim.notify("No stash ID found on the current line.", vim.log.levels.WARN)
            return
        end

        local out, c = api.exec({ "stash", "diff", id })
        if c ~= 0 then
            vim.notify("Failed to diff stash " .. id .. ":\n" .. table.concat(out, "\n"), vim.log.levels.ERROR)
            return
        end

        local diff_buf = window.open_scratch_buffer("Fossil Stash Diff " .. id, out)
        vim.api.nvim_set_option_value("filetype", "diff", { buf = diff_buf })
    end

    vim.keymap.set("n", "<CR>", stash_diff, { buffer = buf, desc = "Show diff for stash under cursor" })
    vim.keymap.set("n", "a", stash_action("apply"), { buffer = buf, desc = "Apply stash under cursor" })
    vim.keymap.set("n", "p", stash_action("pop"), { buffer = buf, desc = "Pop stash under cursor" })
    vim.keymap.set("n", "d", stash_action("drop"), { buffer = buf, desc = "Drop stash under cursor" })
    vim.keymap.set("n", "R", refresh, { buffer = buf, desc = "Refresh stash list" })
    vim.keymap.set("n", "q", "<cmd>q<cr>", { buffer = buf, desc = "Close stash window" })

    vim.notify("Stash UI mappings: <CR>(diff), a(apply), p(pop), d(drop), R(refresh), q(quit)", vim.log.levels.INFO)
end

return M
