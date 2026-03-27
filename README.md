# fossil.nvim

A Neovim plugin for Fossil SCM, inspired by [vim-fugitive](https://github.com/tpope/vim-fugitive).

`fossil.nvim` provides a set of tools to interact with your Fossil repositories without leaving your editor. It features a status window to view changes, stage, and commit files, as well as commands to run any `fossil` command directly from Neovim.

## Features

- **Status Window**: A dedicated interactive window to view untracked, added, and edited files.
- **Diff View**: Quickly view diffs of your changes with Neovim's syntax highlighting.
- **Commit Flow**: Write commit messages directly in a Neovim buffer.
- **Blame/Annotate**: View blame/annotation for a file in a dedicated buffer.
- **Seamless Commands**: Run fossil commands, map outputs to quickfix/location lists, background processes, or open output in splits.

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'wow12345678/fossil.nvim',
  config = function()
    require('fossil').setup()
  end
}
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "wow12345678/fossil.nvim",
  config = function()
    require("fossil").setup()
  end
}
```

## Usage

The primary command is `:Fossil`. For full documentation of all commands, mappings, and APIs, open Neovim and run `:help fossil` or `:help fossil-commands`.

A few common commands to get started:

- `:Fossil` or `:Fossil status`: Opens the interactive Fossil status window.
- `:Fossil diff [file]`: Opens a scratch buffer with the diff output.
- `:Fossil commit`: Opens a commit buffer to type your commit message. Save and quit (`:wq`) to perform the commit.
- `:Fossil add <file>`: Adds the specified file.
- `:Fossil rm <file>`: Removes the specified file.
- `:Fossil blame <file>`: Opens a blame view in a scroll-bound split.
- `:Fossil wq [file]`: Writes the current buffer, adds it to fossil, and quits (like `:Gwq`).

You can also run any other fossil command using `:Fossil <command> [args...]`. For example, `:Fossil branch` or `:Fossil timeline`.

## Documentation

Full documentation is available via Vim's built-in help system. See `:help fossil.txt` after installation.

## Customization

You can initialize the plugin with `require("fossil").setup(opts)` where `opts` is a table of configuration options (currently reserved for future use).
