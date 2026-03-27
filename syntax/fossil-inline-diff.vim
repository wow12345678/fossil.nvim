if exists("b:current_syntax")
  finish
endif

syn match fossilDiffAdd    "^+"
syn match fossilDiffRemove "^-"

hi def link fossilDiffAdd    DiffAdd
hi def link fossilDiffRemove DiffDelete

let b:current_syntax = "fossil-inline-diff"