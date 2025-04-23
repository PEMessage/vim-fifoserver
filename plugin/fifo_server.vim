" plugin/fifo_server.vim
if exists("g:loaded_fifo_server")
  finish
endif
let g:loaded_fifo_server = 1

if !has('python3')
  echo "Error: Requires Vim compiled with +python3"
  finish
endif

command! -nargs=? -complete=file FIFOStart call fifo_server#Start(<q-args>)
command! FIFOStop call fifo_server#Stop()
command! FIFORestart call fifo_server#Restart()

