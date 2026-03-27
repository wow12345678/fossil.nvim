if exists("b:current_syntax")
  finish
endif

" The commit template uses '-' for ignored lines by default according to our lua code
syn match fossilComment "^-.*"
syn match fossilSeparator "^---------------------------------------------------.*"

hi def link fossilComment Comment
hi def link fossilSeparator Comment

let b:current_syntax = "fossilcommit"
