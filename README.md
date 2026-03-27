# fossil.nvim

A Neovim plugin for Fossil SCM, inspired by [vim-fugitive](https://github.com/tpope/vim-fugitive).

`fossil.nvim` provides a set of tools to interact with your Fossil repositories without leaving your editor. It features a status window to view changes, stage, and commit files, as well as commands to run any `fossil` command directly from Neovim.

## Features

- **Status Window**: A dedicated interactive window to view untracked, added, edited, and missing files. Emulates a staging area with mappings like `-` to selectively track untracked files or remove missing files.
- **Diff View**: Quickly view diffs of your changes with Neovim's syntax highlighting.
- **Commit Flow**: Write commit messages directly in a Neovim buffer. The commit buffer is automatically populated with a commented list of staged and untracked files so you have context while writing your message.
- **Interactive Timeline**: View the repository log (`fossil timeline`), view commit details, diffs, and easily checkout past check-ins.
- **File History**: Track the history of the current file (`fossil finfo`), view older versions, or perform two-way diffs between historic versions and your working copy.
- **Blame/Annotate**: View blame/annotation for a file in a dedicated buffer.
- **Branch Management**: Interactive UI to view, checkout, create, and close branches.
- **Ticket Tracking**: Interactive UI to view tickets, edit ticket fields, create tickets, and read ticket history directly inside Neovim.
- **Wiki Management**: Browse and edit Fossil wiki pages (`fossil wiki`). Changes are committed back automatically on buffer save.
- **Workspace State Management**: Seamlessly run undo and redo commands (`:Fossil undo` / `:Fossil redo`) that automatically update Neovim buffers and status UI.
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

The primary command is `:Fossil` (or the shorter `:F` alias). For full documentation of all commands, mappings, and APIs, open Neovim and run `:help fossil` or `:help fossil-commands`.

A few common commands to get started:

- `:Fossil` or `:Fossil status`: Opens the interactive Fossil status window.
- `:Fossil diff [file]`: Opens a scratch buffer with the diff output.
- `:Fossil commit` (or `:FCommit`): Opens a commit buffer to type your commit message. Save and quit (`:wq`) to perform the commit.
- `:Fossil branch` (or `:FBranch`): Opens an interactive branch management window.
- `:Fossil ticket` (or `:FTicket`): Opens an interactive ticket tracker window.
- `:Fossil wiki` (or `:FWiki`): Opens an interactive wiki page list to edit or create pages.
- `:Fossil undo` / `:Fossil redo` (or `:FUndo` / `:FRedo`): Undoes or redoes recent checkout/merge operations.
- `:Fossil add <file>` (or `:FAdd <file>`): Adds the specified file.
- `:Fossil rm <file>` (or `:FRm <file>`): Removes the specified file.
- `:Fossil blame <file>` (or `:FBlame <file>`): Opens a blame view in a scroll-bound split.
- `:Fossil wq [file]` (or `:FWq [file]`): Writes the current buffer, adds it to fossil, and quits (like `:Gwq`).

You can also run any other fossil command using `:F[ossil] <command> [args...]`. For example, `:F branch` or `:F timeline`. Every `:Fossil <command>` also has a `:F<command>` variant (like `:FStatus`, `:FCommit`, `:FDiffsplit`, etc).

## Documentation

Full documentation is available via Vim's built-in help system. See `:help fossil.txt` after installation.

## Customization

You can initialize the plugin with `require("fossil").setup(opts)` where `opts` is a table of configuration options (currently reserved for future use).
