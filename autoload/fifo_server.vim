" autoload/fifo_server.vim
function! fifo_server#Start(...) abort
  let l:fifo_path = a:0 ? a:1 : '~/.cache/vim/fifo/public.fifo'
  execute 'py3 import fifo_server; fifo_server.start_fifo_server(vim.eval("l:fifo_path"))'
endfunction

function! fifo_server#Stop() abort
  py3 fifo_server.stop_fifo_server()
endfunction

function! fifo_server#Restart() abort
  py3 fifo_server.restart_fifo_server()
endfunction
