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
vim.api.nvim_create_user_command("FStatus", function()
    fossil_command.execute({ "status" })
end, {})
vim.api.nvim_create_user_command("FCommit", function(opts)
    fossil_command.execute({ "commit", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FBlame", function(opts)
    fossil_command.execute({ "blame", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FDiffsplit", function(opts)
    fossil_command.execute({ "diffsplit", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FVdiffsplit", function(opts)
    fossil_command.execute({ "vdiffsplit", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FHdiffsplit", function(opts)
    fossil_command.execute({ "hdiffsplit", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FDifftool", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "difftool", unpack(args) })
end, { bang = true, nargs = "*" })
vim.api.nvim_create_user_command("FMergetool", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "mergetool", unpack(args) })
end, { bang = true, nargs = "*" })
vim.api.nvim_create_user_command("FGrep", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "grep", unpack(args) })
end, { bang = true, nargs = "+" })
vim.api.nvim_create_user_command("FClog", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "clog", unpack(args) })
end, { bang = true, nargs = "*" })
vim.api.nvim_create_user_command("FRead", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "read", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FWrite", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "write", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FEdit", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "edit", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FBrowse", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "browse", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FCheckout", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "checkout", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FBranch", function(opts)
    fossil_command.execute({ "branch", unpack(opts.fargs) })
end, { nargs = "*" })
vim.api.nvim_create_user_command("FTicket", function(opts)
    fossil_command.execute({ "ticket", unpack(opts.fargs) })
end, { nargs = "*" })
vim.api.nvim_create_user_command("FWiki", function(opts)
    fossil_command.execute({ "wiki", unpack(opts.fargs) })
end, { nargs = "*" })
vim.api.nvim_create_user_command("FTimeline", function(opts)
    fossil_command.execute({ "timeline", unpack(opts.fargs) })
end, { nargs = "*" })
vim.api.nvim_create_user_command("FFinfo", function(opts)
    fossil_command.execute({ "finfo", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FUndo", function(opts)
    fossil_command.execute({ "undo", unpack(opts.fargs) })
end, { nargs = "*" })
vim.api.nvim_create_user_command("FRedo", function(opts)
    fossil_command.execute({ "redo", unpack(opts.fargs) })
end, { nargs = "*" })
vim.api.nvim_create_user_command("FCo", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "checkout", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FTag", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "tag", unpack(args) })
end, { bang = true, nargs = "*" })
vim.api.nvim_create_user_command("FShow", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "show", unpack(args) })
end, { bang = true, nargs = "*" })
vim.api.nvim_create_user_command("FInfo", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "info", unpack(args) })
end, { bang = true, nargs = "*" })
vim.api.nvim_create_user_command("FAdd", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "add", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FDelete", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "delete", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FRemove", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "delete", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FRm", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "delete", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FUnlink", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "unlink", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FMove", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "move", unpack(args) })
end, { bang = true, nargs = "+", complete = "file" })
vim.api.nvim_create_user_command("FRename", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "rename", unpack(args) })
end, { bang = true, nargs = "+", complete = "file" })
vim.api.nvim_create_user_command("FCd", function()
    fossil_command.execute({ "cd" })
end, {})
vim.api.nvim_create_user_command("FLcd", function()
    fossil_command.execute({ "lcd" })
end, {})
vim.api.nvim_create_user_command("FSplit", function(opts)
    fossil_command.execute({ "split", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FVsplit", function(opts)
    fossil_command.execute({ "vsplit", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FTabedit", function(opts)
    fossil_command.execute({ "tabedit", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FPedit", function(opts)
    fossil_command.execute({ "pedit", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FDrop", function(opts)
    fossil_command.execute({ "drop", unpack(opts.fargs) })
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FLgrep", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "lgrep", unpack(args) })
end, { bang = true, nargs = "+" })
vim.api.nvim_create_user_command("FGllog", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "gllog", unpack(args) })
end, { bang = true, nargs = "*" })
vim.api.nvim_create_user_command("FWq", function(opts)
    local args = vim.deepcopy(opts.fargs)
    if opts.bang then
        table.insert(args, 1, "!")
    end
    fossil_command.execute({ "wq", unpack(args) })
end, { bang = true, nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("FPush", function(opts)
    fossil_command.execute({ "push", unpack(opts.fargs) })
end, { nargs = "*" })
vim.api.nvim_create_user_command("FPull", function(opts)
    fossil_command.execute({ "pull", unpack(opts.fargs) })
end, { nargs = "*" })
vim.api.nvim_create_user_command("FSync", function(opts)
    fossil_command.execute({ "sync", unpack(opts.fargs) })
end, { nargs = "*" })
vim.api.nvim_create_user_command("FFetch", function(opts)
    fossil_command.execute({ "fetch", unpack(opts.fargs) })
end, { nargs = "*" })

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
