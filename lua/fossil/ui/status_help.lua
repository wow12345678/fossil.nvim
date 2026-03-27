local M = {}

function M.open_help()
    local lines = {
        "==================================================================",
        "|                    Fossil Status Keybindings                   |",
        "==================================================================",
        "",
        " [ File Navigation ]",
        "   <CR>  Open file under cursor in current window",
        "   o     Open file in a new horizontal split",
        "   gO    Open file in a new vertical split",
        "   O     Open file in a new tab",
        "   p     Open file in preview window",
        "   )     Jump to the next file",
        "   (     Jump to the previous file",
        "   ]/    Jump to the next file",
        "   [/    Jump to the previous file",
        "   ]c    Jump to the next inline diff hunk",
        "   [c    Jump to the previous inline diff hunk",
        "   gu    Jump to the Untracked section",
        "   gU    Jump to the Unstaged/Changes section",
        "   gs    Jump to the Staged/Changes section",
        "",
        " [ Staging & Discarding ]",
        "   s     Stage (add) file or section under cursor",
        "   u     Unstage (untrack) file or section under cursor",
        "   -     Toggle stage/unstage status for file or section under cursor",
        "   U     Unstage (rm --soft) all added files",
        "   X     Discard changes for file or section under cursor",
        "",
        " [ Diffing & Review ]",
        "   dd    Open diff in a split (internal default)",
        "   dv    Open diff in a vertical split",
        "   ds    Open diff in a horizontal split",
        "   dh    Open diff in a horizontal split",
        "   dp    Show plain diff output in a scratch buffer",
        "   dq    Close all diff buffers and run :diffoff!",
        "   =     Toggle inline diff for the file under cursor",
        "   >     Expand inline diff for the file",
        "   <     Collapse inline diff for the file",
        "",
        " [ Repository Actions ]",
        "   cc    Open commit window to commit staged changes",
        "   cl    Open the repository timeline/log",
        "   czz   Push changes to the stash (fossil stash save)",
        "   cza   Select a stash to apply",
        "   czp   Select a stash to pop",
        "   czA   Apply the most recent stash instantly",
        "   czP   Pop the most recent stash instantly",
        "   R     Refresh the status window",
        "",
        " [ Command Line Population ]",
        "   c<Space>  Populate command line with :F commit ",
        "   cb<Space> Populate command line with :F branch ",
        "   co<Space> Populate command line with :F checkout ",
        "   cr<Space> Populate command line with :F revert ",
        "   cm<Space> Populate command line with :F merge ",
        "   cz<Space> Populate command line with :F stash ",
        "   .         Populate command line with :F and file under cursor",
        "",
        " [ General ]",
        "   g?    Show this help message",
        "   gq    Close the status window",
        "   q     Close the status window / Close this help window",
        "",
        "==================================================================",
    }

    vim.cmd("botright new")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(buf, "Fossil Help")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
    vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    vim.api.nvim_set_option_value("filetype", "fossilhelp", { buf = buf })

    -- Add basic syntax highlighting for the help menu
    local syntax_cmds = [[
		if exists("b:current_syntax")
		  finish
		endif

		syn match fossilHelpHeader "^ \[ .* \]$"
		syn match fossilHelpKey "^\s\+\S\+\s"
		syn match fossilHelpBorder "^====.*"
		syn match fossilHelpTitle "^|.*|$"

		hi def link fossilHelpHeader Title
		hi def link fossilHelpKey Special
		hi def link fossilHelpBorder Comment
		hi def link fossilHelpTitle String

		let b:current_syntax = "fossilhelp"
	]]
    vim.cmd(syntax_cmds)

    vim.keymap.set("n", "q", "<cmd>q<cr>", { buffer = buf, silent = true, noremap = true })
end

return M
