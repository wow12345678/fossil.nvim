# fossil.nvim

A Neovim plugin for Fossil SCM, inspired by [vim-fugitive](https://github.com/tpope/vim-fugitive).

`fossil.nvim` provides a set of tools to interact with your Fossil repositories without leaving your editor. It features a status window to view changes, stage, and commit files, as well as commands to run any `fossil` command directly from Neovim.

## Features

- **Status Window**: A dedicated window to view untracked, added, and edited files.
- **Diff View**: Quickly view diffs of your changes with Neovim's syntax highlighting.
- **Commit Flow**: Write commit messages directly in a Neovim buffer.
- **Blame/Annotate**: View blame/annotation for a file in a dedicated buffer.

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'yourusername/fossil.nvim',
  config = function()
    require('fossil').setup()
  end
}
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "yourusername/fossil.nvim",
  config = function()
    require("fossil").setup()
  end
}
```

## Usage

The primary command is `:Fossil`. For full documentation, open Neovim and run `:help fossil` or `:help fossil-commands`.

- `:Fossil` or `:Fossil status`: Opens the Fossil status window.
- `:Fossil diff [file]`: Opens a scratch buffer with the diff output.
- `:Fossil commit`: Opens a commit buffer to type your commit message. Save and quit (`:wq`) to perform the commit.
- `:Fossil add <file>`: Adds the specified file.
- `:Fossil rm <file>`: Removes the specified file.
- `:Fossil blame <file>` or `:Fossil annotate <file>`: Opens a blame view in a scroll-bound split.
- `:Fossil diffsplit [file]`: Opens a diff split for the file (defaults to current buffer).
- `:Fossil vdiffsplit [file]`: Opens a vertical diff split for the file.
- `:Fossil hdiffsplit [file]`: Opens a horizontal diff split for the file.
- `:Fossil difftool [args]`: Populates quickfix with `fossil diff` output.
- `:Fossil grep <pattern> <file ...>`: Populates quickfix with `fossil grep` results.
- `:Fossil clog [args]`: Populates quickfix with a fossil log listing.
- `:Fossil read [file]`: Reads the file's content from fossil (like `:Gread`).
- `:Fossil write [file]`: Writes the current buffer and adds it to fossil (like `:Gwrite`).
- `:Fossil edit [file]`: Opens the file in a new buffer (like `:Gedit`).
- `:Fossil browse [file]`: Opens the file or repo in the browser using the remote URL (like `:GBrowse`).

You can also run any other fossil command using `:Fossil <command> [args...]`. For example, `:Fossil branch` or `:Fossil timeline`.

### Status Window Mappings

When the status window is open (`:Fossil status`), you can use the following default mappings (Fugitive-inspired):

- `<CR>`: Open the file under the cursor.
- `o`: Open the file in a horizontal split.
- `gO`: Open the file in a vertical split.
- `O`: Open the file in a new tab.
- `p`: Open the file in a preview window.
- `)`: Jump to the next file.
- `(`: Jump to the previous file.
- `dd`: Diff split for the file under the cursor.
- `dv`: Vertical diff split for the file under the cursor.
- `ds`/`dh`: Horizontal diff split for the file under the cursor.
- `dp`: Open a diff output buffer for the file under the cursor.
- `=`: Toggle inline diff under the file.
- `>`: Insert inline diff under the file.
- `<`: Remove inline diff under the file.
- `s`: Add (stage) an untracked file.
- `u`: Untrack a newly added file.
- `-`: Toggle add/untrack for new files.
- `X`: Discard changes (revert tracked files, clean untracked files).
- `cc`: Open the commit message buffer.
- `ll`: Open the repository timeline/log.
- `czz`: Push changes to the stash (`fossil stash save`).
- `R`: Refresh the status window.
- `g?`: Open the status help buffer.
- `q` or `gq`: Close the status window.

## Customization

You can initialize the plugin with `require("fossil").setup(opts)` where `opts` is a table of configuration options (currently reserved for future use).
