local api = require("fossil.api")
local window = require("fossil.ui.window")

local M = {}

--- Open a buffer for editing a wiki page
--- @param page_name string The name of the wiki page
local function edit_wiki_page(page_name)
    local out, c = api.exec({ "wiki", "export", page_name })
    local is_new = (c ~= 0)
    if is_new then
        -- It might not exist, that's fine for a new page
        out = { "<!-- Enter wiki content here for: " .. page_name .. " -->", "" }
    end

    vim.cmd("tabnew")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(buf, "fossil://wiki/" .. page_name:gsub("/", "_") .. " - " .. tostring(os.time()))
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)

    vim.api.nvim_set_option_value("buftype", "acwrite", { buf = buf })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
    vim.api.nvim_set_option_value("modified", false, { buf = buf })

    vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        callback = function()
            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            local tmp = vim.fn.tempname()
            local f = io.open(tmp, "w")
            if f then
                f:write(table.concat(lines, "\n"))
                f:close()

                local cout, cc
                if is_new then
                    cout, cc = api.exec({ "wiki", "create", page_name, tmp })
                else
                    cout, cc = api.exec({ "wiki", "commit", page_name, tmp })
                end

                os.remove(tmp)

                if cc == 0 then
                    is_new = false -- subsequent saves should commit
                    vim.notify("Saved wiki page: " .. page_name, vim.log.levels.INFO)
                    vim.api.nvim_set_option_value("modified", false, { buf = buf })
                else
                    vim.notify("Failed to save wiki page:\n" .. table.concat(cout, "\n"), vim.log.levels.ERROR)
                end
            end
        end,
    })
end

function M.open_wiki_window()
    local output, code = api.exec({ "wiki", "ls" })
    if code ~= 0 then
        vim.notify("Failed to list wiki pages.", vim.log.levels.ERROR)
        return
    end

    vim.cmd("botright new")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(buf, "Fossil Wiki - " .. tostring(os.time()))

    local lines = {
        "==================================================================",
        "|                        Fossil Wiki                             |",
        "==================================================================",
        " <CR>  Edit the wiki page under cursor",
        " c     Create/Edit a new wiki page",
        " q     Close this window",
        "==================================================================",
        "",
    }

    for _, line in ipairs(output) do
        if line ~= "" then
            table.insert(lines, "  " .. line)
        end
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
    vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    vim.api.nvim_set_option_value("filetype", "fossilwiki", { buf = buf })

    local syntax_cmds = [[
		if exists("b:current_syntax")
		  finish
		endif

		syn match fossilWikiHeader "^====.*"
		syn match fossilWikiTitle "^|.*|$"
		syn match fossilWikiKey "^\s\+\S\+\s"

		hi def link fossilWikiHeader Comment
		hi def link fossilWikiTitle Type
		hi def link fossilWikiKey Special

		let b:current_syntax = "fossilwiki"
	]]
    vim.cmd(syntax_cmds)

    local opts = { buffer = buf, silent = true, noremap = true }

    local function get_page_under_cursor()
        local line = vim.api.nvim_get_current_line()
        if line:match("^=*") or line:match("^|") or line:match("^ <") or line:match("^ [a-z] ") or line == "" then
            return nil
        end
        local page = line:match("^%s*(.+)$")
        return page
    end

    vim.keymap.set("n", "<CR>", function()
        local page = get_page_under_cursor()
        if not page then
            return
        end
        edit_wiki_page(page)
    end, opts)

    vim.keymap.set("n", "c", function()
        vim.ui.input({ prompt = "Wiki Page Name: " }, function(input)
            if input and input ~= "" then
                edit_wiki_page(input)
            end
        end)
    end, opts)

    vim.keymap.set("n", "q", "<cmd>q<cr>", opts)
end

return M
