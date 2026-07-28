vim9script

g:previewcmd_winid = 0

augroup previewcmd
  autocmd!
  autocmd CmdlineChanged * previewcmd#SafeStart()
  autocmd CmdlineLeave * previewcmd#SafeClose()
augroup END

