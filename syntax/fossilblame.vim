if exists("b:current_syntax")
  finish
endif

syn match fossilBlameHash "^\S\+\s\+" contained
syn match fossilBlameDate "\d\{4}-\d\{2}-\d\{2}\s\+" contained
syn match fossilBlameLine "^\S\+\s\+\d\{4}-\d\{2}-\d\{2}\s\+\d\+: " contains=fossilBlameHash,fossilBlameDate

hi def link fossilBlameHash Identifier
hi def link fossilBlameDate String

let b:current_syntax = "fossilblame"
