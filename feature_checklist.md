# Fugitive.nvim Feature Checklist

This is a comprehensive checklist of features found in `fugitive.nvim` based on its documentation, to serve as a guide for implementing equivalent functionality.

## Core Commands
- [x] `:G` / `:Git` (Alias for the main command)
- [x] `:Git` (With no arguments: open status/summary window)
- [x] `:Git {args}` (Run arbitrary git command)
- [x] `:Git! {args}` (Run in background, stream output to preview window)
- [x] `:Git --paginate {args}` / `-p` (Capture output to temp buffer, open in split)

## Specific Git Commands
- [x] `:Git blame [flags]` (Scroll-bound vertical split for blame)
- [x] `:Git difftool [args]` (Populate quickfix with diffs)
- [x] `:Git difftool -y [args]` (Open each changed file in a new tab)
- [x] `:Git mergetool [args]` (Target merge conflicts)

## Wrappers for Vim built-ins
- [x] `:Ggrep` / `:Git grep` (Approximation of `:grep`)
- [x] `:Glgrep` (Approximation of `:lgrep` - uses location list)
- [x] `:Gclog` (Load commit history into quickfix list)
- [x] `:Gllog` (Load commit history into location list)
- [x] `:Gcd` (`:cd` relative to repository)
- [x] `:Glcd` (`:lcd` relative to repository)
- [x] `:Gedit` (`:edit` a git object)
- [x] `:Gsplit` (`:split` a git object)
- [x] `:Gvsplit` (`:vsplit` a git object)
- [x] `:Gtabedit` (`:tabedit` a git object)
- [x] `:Gpedit` (`:pedit` a git object)
- [x] `:Gdrop` (`:drop` a git object)
- [x] `:Gread` (Empty buffer and read a git object)
- [x] `:Gwrite` (Write to path and stage results)
- [x] `:Gwq` (`:Gwrite` followed by `:quit`)
- [x] `:Gdiffsplit` (Perform a vimdiff against given file/commit)
- [x] `:Gdiffsplit!` (Retain focus on current window)
- [x] `:Gvdiffsplit` (Vertical diff split)
- [x] `:Ghdiffsplit` (Horizontal diff split)

## Other File Operations
- [x] `:GMove` (Wrapper around `git-mv`)
- [x] `:GRename` (Like `GMove` but relative to current file's directory)
- [x] `:GDelete` (Wrapper around `git-rm`)
- [x] `:GRemove` / `:GUnlink` (Like `GDelete` but keep the empty buffer around)
- [x] `:GBrowse` (Open file/blob/tree/commit in upstream hosting provider)

## Maps (Status buffer / object buffers)
### Staging / Unstaging
- [x] `s` (Stage file/hunk)
- [x] `u` (Unstage file/hunk)
- [x] `-` (Toggle stage/unstage)
- [x] `U` (Unstage everything)
- [x] `X` (Discard changes)

### Inline Diffs
- [x] `=` (Toggle inline diff)
- [x] `>` (Insert inline diff)
- [x] `<` (Remove inline diff)

### Ignore & Add
- [!] `gI` (Open `.git/info/exclude` / `.gitignore` - Note: Fossil uses `.fossil-settings/ignore-glob`)
- [!] `I` / `P` (Patch add/reset - Note: Fossil does not have a native interactive patch staging mechanism)

### Diff Maps
- [x] `dp` (Invoke git diff - deprecated for inline)
- [x] `dd` (`:Gdiffsplit`)
- [x] `dv` (`:Gvdiffsplit`)
- [x] `ds` / `dh` (`:Ghdiffsplit`)
- [x] `dq` (Close diff buffers, `:diffoff!`)
- [x] `d?` (Help)

### Navigation Maps
- [x] `<CR>` (Open file/object)
- [x] `o` (Open in split)
- [x] `gO` (Open in vertical split)
- [x] `O` (Open in new tab)
- [x] `p` (Open in preview window)
- [!] `~` (Open in [count]th first ancestor - complex in Fossil inline diffs)
- [!] `P` (Open in [count]th parent)
- [!] `C` (Open commit containing current file - Needs object parsing mapping)
- [x] `(` (Previous file/hunk/revision)
- [x] `)` (Next file/hunk/revision)
- [x] `[c` (Previous hunk, expanding inline diffs)
- [x] `]c` (Next hunk, expanding inline diffs)
- [x] `[/` / `[m` (Previous file, collapsing inline diffs)
- [x] `]/` / `]m` (Next file, collapsing inline diffs)
- [!] `i` (Next file/hunk, expanding inline diffs - complex)
- [!] `[[` / `]]` / `[]` / `][` (Jump sections - Not fully mapped)
- [!] `*` / `#` (Search for corresponding +/- diff line - Missing structural inline parsing)
- [x] `gu` / `gU` / `gs` / `gp` / `gP` / `gr` (Jump to sections: untracked, unstaged, staged, unpushed, unpulled, rebasing)
- [!] `gi` (Open `.gitignore` - Note: Fossil uses `.fossil-settings/ignore-glob`)

### Commit Maps
- [x] `cc` (Create commit)
- [!] `cvc` (Commit with `-v` - Not directly mapped yet)
- [!] `ca` (Amend commit - See note below)
- [!] `cva` (Amend with `-v`)
- [!] `ce` (Amend without editing message)
- [!] `cw` / `cW` (Reword commit - Note: Could be mapped to fossil amend)
- [!] `cf` / `cF` (Fixup commit - Note: Not applicable for fossil as it doesn't rewrite history like Git)
- [!] `cs` / `cS` (Squash commit - Note: Not applicable for fossil)
- [!] `cn` (Squash and edit message - Note: Not applicable for fossil)
- [x] `c<Space>` (Populate command line)
- [!] `crc` / `crn` / `cr<Space>` (Revert commit maps)
- [x] `cm<Space>` (Merge command line)

### Checkout/Branch Maps
- [!] `coo` (Checkout commit - Not mapped correctly yet)
- [x] `cb<Space>` / `co<Space>` (Branch/checkout command line)

### Stash Maps
- [x] `czz` / `czw` / `czs` (Push stash variations - Partially implemented with czz)
- [x] `czA` / `cza` (Apply stash)
- [x] `czP` / `czp` (Pop stash)
- [x] `cz<Space>` (Stash command line)

### Rebase Maps
- [!] `ri` / `ru` / `rp` / `rf` (Start rebase - Note: Interactive rebasing is not applicable in Fossil)
- [!] `rr` (Continue)
- [!] `rs` (Skip)
- [!] `ra` (Abort)
- [!] `re` (Edit todo list - Note: Not applicable)
- [!] `rw` / `rm` / `rd` (Set commit to reword/edit/drop - Note: Not applicable)
- [x] `r<Space>` (Rebase command line)

### Miscellaneous Maps
- [x] `gq` (Close status buffer)
- [x] `.` (Start command line with prepopulated file)
- [x] `g?` (Help)

### Global Maps
- [x] `<C-R><C-G>` (Recall path to current object on command line)
- [x] `y<C-G>` (Yank path to current object)

## Other Features
- [!] **Fugitive Objects**: Support for specifying git objects (like `@`, `master^`, `:Makefile`, `:%`, `!`) - Note: Fossil parses specific artifact hashes and tags, but object syntax like `@^` is Git specific.
- [x] **Statusline**: `%` indicator `FossilStatusline()` (equivalent to `FugitiveStatusline()`)
- [!] **Autocommands**: Custom `User Fugitive*` events (e.g., `FugitiveCommit`, `FugitiveBlob`, `FugitiveIndex`) - Note: Not currently mapped to Fossil equivalents.