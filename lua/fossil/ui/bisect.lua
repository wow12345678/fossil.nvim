local api = require("fossil.api")
local window = require("fossil.ui.window")

local M = {}

function M.open_bisect_window()
    local output, code = api.exec({ "bisect", "log" })
    local content = output
    if #content == 0 or (code ~= 0 and string.match(table.concat(output, "\n"), "not a bisect")) then
        content = { "Bisect is not active or no log available." }
    end

    local buf = window.open_scratch_buffer("Fossil Bisect", content)

    local function refresh()
        local new_out, new_code = api.exec({ "bisect", "log" })
        local new_content = new_out
        if #new_content == 0 then
            new_content = { "Bisect is not active or no log available." }
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_content)
    end

    local function bisect_action(action)
        return function()
            local out, c = api.exec({ "bisect", action })
            if c ~= 0 then
                vim.notify("Bisect " .. action .. " failed:\n" .. table.concat(out, "\n"), vim.log.levels.ERROR)
            else
                vim.notify("Bisect " .. action .. " successful.", vim.log.levels.INFO)
                vim.defer_fn(function()
                    vim.notify(
                        "Bisect UI mappings: mg(good), mb(bad), ms(skip), mr(reset), i(status), R(refresh), q(quit)",
                        vim.log.levels.INFO
                    )
                end, 3000)
            end
            refresh()
        end
    end

    local function bisect_status()
        local out, c = api.exec({ "bisect" })
        window.open_scratch_buffer("Fossil Bisect Status", out)
    end

    vim.keymap.set("n", "mg", bisect_action("good"), { buffer = buf, desc = "Mark current checkout as good" })
    vim.keymap.set("n", "mb", bisect_action("bad"), { buffer = buf, desc = "Mark current checkout as bad" })
    vim.keymap.set("n", "ms", bisect_action("skip"), { buffer = buf, desc = "Skip current checkout" })
    vim.keymap.set("n", "mr", bisect_action("reset"), { buffer = buf, desc = "Reset bisect state" })
    vim.keymap.set("n", "i", bisect_status, { buffer = buf, desc = "Show bisect status" })
    vim.keymap.set("n", "R", refresh, { buffer = buf, desc = "Refresh bisect log" })
    vim.keymap.set("n", "q", "<cmd>q<cr>", { buffer = buf, desc = "Close bisect window" })

    vim.notify(
        "Bisect UI mappings: mg(good), mb(bad), ms(skip), mr(reset), i(status), R(refresh), q(quit)",
        vim.log.levels.INFO
    )
end

return M
