local api = require("fossil.api")
local window = require("fossil.ui.window")

local M = {}

function M.open_settings_window()
    local output, code = api.exec({ "settings" })
    if code ~= 0 then
        vim.notify("Failed to get settings:\n" .. table.concat(output, "\n"), vim.log.levels.ERROR)
        return
    end

    local buf = window.open_scratch_buffer("Fossil Settings", output)
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

    local function refresh()
        local new_out, new_code = api.exec({ "settings" })
        if new_code == 0 then
            vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_out)
            vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
        end
    end

    local function edit_setting()
        local line = vim.api.nvim_get_current_line()
        -- The line format is usually: name-of-setting      (local)  value
        -- or name-of-setting      value
        local setting_name = string.match(line, "^([%w%-]+)")
        if not setting_name then
            vim.notify("Could not parse setting name from line.", vim.log.levels.WARN)
            return
        end

        vim.ui.input(
            { prompt = "New value for " .. setting_name .. " (empty to unset, prefix with '!' for global): " },
            function(input)
                if not input then
                    return
                end

                local is_global = false
                local value = input

                if string.sub(input, 1, 1) == "!" then
                    is_global = true
                    value = string.sub(input, 2)
                    -- strip optional leading space after !
                    if string.sub(value, 1, 1) == " " then
                        value = string.sub(value, 2)
                    end
                end

                local args = {}
                if value == "" then
                    args = { "unset", setting_name }
                    if is_global then
                        table.insert(args, "--global")
                    end
                else
                    args = { "settings", setting_name, value }
                    if is_global then
                        table.insert(args, "--global")
                    end
                end

                local out, c = api.exec(args)
                if c ~= 0 then
                    vim.notify(
                        "Failed to update " .. setting_name .. ":\n" .. table.concat(out, "\n"),
                        vim.log.levels.ERROR
                    )
                else
                    vim.notify("Setting " .. setting_name .. " updated.", vim.log.levels.INFO)
                end
                refresh()
            end
        )
    end

    vim.keymap.set("n", "<CR>", edit_setting, { buffer = buf, desc = "Edit setting under cursor" })
    vim.keymap.set("n", "R", refresh, { buffer = buf, desc = "Refresh settings list" })
    vim.keymap.set("n", "q", "<cmd>q<cr>", { buffer = buf, desc = "Close settings window" })

    vim.notify("Settings UI mappings: <CR>(edit), R(refresh), q(quit)", vim.log.levels.INFO)
end

return M
