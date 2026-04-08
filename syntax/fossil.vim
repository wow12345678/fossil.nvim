if exists("b:current_syntax")
  finish
endif

" Headers
syntax match fossilHeader "^[A-Za-z]\+:"
syntax match fossilBranch "^Head: \zs.*"
syntax match fossilRemote "^Remote: \zs.*"

" File states
syntax match fossilStateAdded "^\s\+ADDED\s\+"
syntax match fossilStateEdited "^\s\+EDITED\s\+"
syntax match fossilStateDeleted "^\s\+DELETED\s\+"
syntax match fossilStateMissing "^\s\+MISSING\s\+"
syntax match fossilStateUntracked "^\s\+?\s\+"

" Inline diffs
syntax match fossilDiffAdd "^    +.*$"
syntax match fossilDiffRemove "^    -.*$"
syntax match fossilDiffContext "^    @@.*@@"

" Highlight links
highlight default link fossilHeader Title
highlight default link fossilBranch String
highlight default link fossilRemote Underlined

highlight default link fossilStateAdded String
highlight default link fossilStateEdited Identifier
highlight default link fossilStateDeleted Error
highlight default link fossilStateMissing Error
highlight default link fossilStateUntracked WarningMsg

highlight default link fossilDiffAdd DiffAdd
highlight default link fossilDiffRemove DiffDelete
highlight default link fossilDiffContext DiffChange

let b:current_syntax = "fossil"
