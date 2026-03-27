local api = require("fossil.api")
local window = require("fossil.ui.window")

local M = {}

--- Parse hash from a timeline line
--- Format: `12:34:56 [abcdef1234] Commit message (user: foo)`
local function get_hash_under_cursor()
    local line = vim.api.nvim_get_current_line()
    local hash = line:match("%[([0-9a-fA-F]+)%]")
    return hash
end

function M.open_timeline_window()
    local output, code = api.exec({ "timeline" })
    if code ~= 0 then
        vim.notify("Failed to get timeline.", vim.log.levels.ERROR)
        return
    end

    vim.cmd("botright new")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(buf, "Fossil Timeline")

    local lines = {
        "==================================================================",
        "|                        Fossil Timeline                         |",
        "==================================================================",
        " <CR>  View commit details (info)",
        " d     View commit diff (-ci)",
        " c     Checkout this commit",
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
    vim.api.nvim_set_option_value("filetype", "fossiltimeline", { buf = buf })

    -- Basic syntax highlighting
    local syntax_cmds = [[
		if exists("b:current_syntax")
		  finish
		endif

		syn match fossilTimelineHeader "^====.*"
		syn match fossilTimelineTitle "^|.*|$"
		syn match fossilTimelineKey "^\s\+\S\+\s"
		syn match fossilTimelineHash "\[\x\+\]"
		syn match fossilTimelineDate "^===.*==="

		hi def link fossilTimelineHeader Comment
		hi def link fossilTimelineTitle Type
		hi def link fossilTimelineKey Special
		hi def link fossilTimelineHash Identifier
		hi def link fossilTimelineDate String

		let b:current_syntax = "fossiltimeline"
	]]
    vim.cmd(syntax_cmds)

    local opts = { buffer = buf, silent = true, noremap = true }

    vim.keymap.set("n", "<CR>", function()
        local hash = get_hash_under_cursor()
        if not hash then
            return
        end
        local out, c = api.exec({ "info", hash })
        if c == 0 then
            window.open_scratch_buffer("Fossil Info " .. hash, out)
        else
            vim.notify("Failed to get info for " .. hash, vim.log.levels.ERROR)
        end
    end, opts)

    vim.keymap.set("n", "d", function()
        local hash = get_hash_under_cursor()
        if not hash then
            return
        end
        local out, c = api.exec({ "diff", "-ci", hash })
        if c == 0 then
            local diff_buf = window.open_scratch_buffer("Fossil Diff " .. hash, out)
            vim.api.nvim_set_option_value("filetype", "diff", { buf = diff_buf })
        else
            vim.notify("Failed to get diff for " .. hash, vim.log.levels.ERROR)
        end
    end, opts)

    vim.keymap.set("n", "c", function()
        local hash = get_hash_under_cursor()
        if not hash then
            return
        end
        local confirm = vim.fn.confirm("Checkout commit '" .. hash .. "'? (y/N)", "&Yes\n&No", 2)
        if confirm == 1 then
            require("fossil.operations").checkout({ "checkout", hash })
        end
    end, opts)

    vim.keymap.set("n", "q", "<cmd>q<cr>", opts)
end

return M
