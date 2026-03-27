if exists("b:current_syntax")
  finish
endif

syn match fossilHeader "^\(Changes\|Untracked\):$"
syn match fossilUntracked "^  ? .*"
syn match fossilInlineDiff "^  | .*"
syn match fossilAdded "^  ADDED\>.*"
syn match fossilEdited "^  EDITED\>.*"
syn match fossilDeleted "^  DELETED\>.*"
syn match fossilMissing "^  MISSING\>.*"
syn match fossilRenamed "^  RENAMED\>.*"

hi def link fossilHeader Title
hi def link fossilUntracked Comment
hi def link fossilInlineDiff Comment
hi def link fossilAdded String
hi def link fossilEdited Identifier
hi def link fossilDeleted Error
hi def link fossilMissing WarningMsg
hi def link fossilRenamed Special

let b:current_syntax = "fossil"
