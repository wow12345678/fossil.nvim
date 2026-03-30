if vim.g.loaded_fossil == 1 then
    return
end
vim.g.loaded_fossil = 1

local fossil_command = require("fossil.command")

-- The main :Fossil command
local fossil_cmd_opts = {
    bang = true,
    nargs = "*",
    complete = function(arglead, cmdline, cursorpos)
        -- Optional: add completion for common fossil commands like status, diff, commit, add, rm
        local cmds = {
            "status",
            "diff",
            "commit",
            "add",
            "rm",
            "info",
            "branch",
            "ticket",
            "wiki",
            "timeline",
            "finfo",
            "bisect",
            "settings",
            "stash",
            "blame",
            "annotate",
            "diffsplit",
            "vdiffsplit",
            "hdiffsplit",
            "difftool",
            "grep",
            "clog",
            "read",
            "write",
            "edit",
            "browse",
            "checkout",
            "co",
            "tag",
            "show",
            "undo",
            "redo",
            "push",
            "pull",
            "sync",
            "fetch",
        }
        local matches = {}
        for _, cmd in ipairs(cmds) do
            if cmd:find("^" .. arglead) then
                table.insert(matches, cmd)
            end
        end
        return matches
    end,
    desc = "Run a fossil command or open the status window (like :Git)",
}

local fossil_cmd_fn = function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute(args)
end

vim.api.nvim_create_user_command("Fossil", fossil_cmd_fn, fossil_cmd_opts)
vim.api.nvim_create_user_command("F", fossil_cmd_fn, fossil_cmd_opts)

-- Shortcuts
local shortcut_cmds = {
    FStatus = { cmd = "status", nargs = 0 },
    FCommit = { cmd = "commit", nargs = "*", complete = "file" },
    FBlame = { cmd = "blame", nargs = "*", complete = "file" },
    FDiffsplit = { cmd = "diffsplit", nargs = "*", complete = "file" },
    FVdiffsplit = { cmd = "vdiffsplit", nargs = "*", complete = "file" },
    FHdiffsplit = { cmd = "hdiffsplit", nargs = "*", complete = "file" },
    FDifftool = { cmd = "difftool", bang = true, nargs = "*" },
    FMergetool = { cmd = "mergetool", bang = true, nargs = "*" },
    FGrep = { cmd = "grep", bang = true, nargs = "+" },
    FClog = { cmd = "clog", bang = true, nargs = "*" },
    FRead = { cmd = "read", bang = true, nargs = "*", complete = "file" },
    FWrite = { cmd = "write", bang = true, nargs = "*", complete = "file" },
    FEdit = { cmd = "edit", bang = true, nargs = "*", complete = "file" },
    FBrowse = { cmd = "browse", bang = true, nargs = "*", complete = "file" },
    FCheckout = { cmd = "checkout", bang = true, nargs = "*", complete = "file" },
    FBranch = { cmd = "branch", nargs = "*" },
    FTicket = { cmd = "ticket", nargs = "*" },
    FWiki = { cmd = "wiki", nargs = "*" },
    FTimeline = { cmd = "timeline", nargs = "*" },
    FFinfo = { cmd = "finfo", nargs = "*", complete = "file" },
    FBisect = { cmd = "bisect", nargs = "*" },
    FSettings = { cmd = "settings", nargs = "*" },
    FStash = { cmd = "stash", nargs = "*" },
    FUndo = { cmd = "undo", nargs = "*" },
    FRedo = { cmd = "redo", nargs = "*" },
    FCo = { cmd = "checkout", bang = true, nargs = "*", complete = "file" },
    FTag = { cmd = "tag", bang = true, nargs = "*" },
    FInfo = { cmd = "info", bang = true, nargs = "*" },
    FAdd = { cmd = "add", bang = true, nargs = "*", complete = "file" },
    FDelete = { cmd = "delete", bang = true, nargs = "*", complete = "file" },
    FRemove = { cmd = "delete", bang = true, nargs = "*", complete = "file" },
    FRm = { cmd = "delete", bang = true, nargs = "*", complete = "file" },
    FUnlink = { cmd = "unlink", bang = true, nargs = "*", complete = "file" },
    FMove = { cmd = "move", bang = true, nargs = "+", complete = "file" },
    FRename = { cmd = "rename", bang = true, nargs = "+", complete = "file" },
    FCd = { cmd = "cd", nargs = 0 },
    FLcd = { cmd = "lcd", nargs = 0 },
    FSplit = { cmd = "split", nargs = "*", complete = "file" },
    FVsplit = { cmd = "vsplit", nargs = "*", complete = "file" },
    FTabedit = { cmd = "tabedit", nargs = "*", complete = "file" },
    FPedit = { cmd = "pedit", nargs = "*", complete = "file" },
    FLgrep = { cmd = "lgrep", bang = true, nargs = "+" },
    FGllog = { cmd = "gllog", bang = true, nargs = "*" },
    FWq = { cmd = "wq", bang = true, nargs = "*", complete = "file" },
    FPush = { cmd = "push", nargs = "*" },
    FPull = { cmd = "pull", nargs = "*" },
    FSync = { cmd = "sync", nargs = "*" },
    FFetch = { cmd = "fetch", nargs = "*" },
}

for name, def in pairs(shortcut_cmds) do
    local opts = {}
    if def.nargs then
        opts.nargs = def.nargs
    end
    if def.bang then
        opts.bang = def.bang
    end
    if def.complete then
        opts.complete = def.complete
    end

    vim.api.nvim_create_user_command(name, function(args)
        local cmd_args = { def.cmd }
        if args.bang then
            table.insert(cmd_args, 1, "!")
        end
        for _, arg in ipairs(args.fargs) do
            table.insert(cmd_args, arg)
        end
        fossil_command.execute(cmd_args)
    end, opts)
end

if vim.g.fossil_no_maps ~= 1 then
    vim.keymap.set("n", "y<C-G>", function()
        local path = require("fossil.util").get_relative_path()
        if path ~= "" then
            vim.fn.setreg('"', path)
            vim.fn.setreg("0", path)
            vim.notify("Yanked: " .. path, vim.log.levels.INFO)
        end
    end, { desc = "Yank fossil relative path" })

    vim.keymap.set("c", "<C-R><C-G>", function()
        return require("fossil.util").get_relative_path()
    end, { expr = true, desc = "Insert fossil relative path" })
end

-- Statusline integration
local statusline_cache = {}

--- Returns a string suitable for inclusion in the statusline, caching the result
--- @return string
function _G.FossilStatusline()
    local root = require("fossil.util").get_repo_root()
    if not root then
        return ""
    end

    local now = vim.uv.now()
    local cache = statusline_cache[root]

    if cache and (now - cache.time < 5000) then
        return cache.text
    end

    local output, code = require("fossil.api").exec({ "branch", "current" })
    if code == 0 and output[1] then
        local text = "[Fossil(" .. output[1] .. ")]"
        statusline_cache[root] = { time = now, text = text }
        return text
    end

    return ""
end
