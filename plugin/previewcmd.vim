vim9script

var winid = 0
var excmd = []
var usercmd = []
var pos = 0

augroup previewcmd
  autocmd!
  autocmd CmdlineChanged * OnCmdlineChanged()
  autocmd CmdlineLeave * ClosePopup()
augroup END

def OnCmdlineChanged()
  try
    Main()
  catch
    g:previewcmd_lastexception = v:exception
  endtry
enddef


def Main()
  InitConfig()
  if !g:previewcmd.enable
    # NOP
  elseif !winid
    timer_start(g:previewcmd.delay, Open)
  else
    Update()
  endif
enddef

def InitConfig()
  if !exists('g:previewcmd.initilized')
    g:previewcmd = {
      delay: 100,
      maxheight: 10,
      fuzzy: true,
      enable: true,
      initilized: true,
    }->extend(get(g:, 'previewcmd', {}))
  endif
enddef

def Open(_: number)
  if mode() ==# 'c' && getcmdtype() ==# ':'
    SetupExCmd()
    SetupUserCmd()
    Update()
  endif
enddef

def Update()
  if getcmdline() =~# '[ /]'
    ClosePopup()
    return
  endif

  const cmd = getcmdline()->matchstr('[a-zA-Z][a-zA-Z0-9_/]*$')
  if !cmd
    ClosePopup()
    return
  endif

  pos = getcmdline()->len() - cmd->len()

  const items = (excmd + usercmd)->FilterCmd(cmd)
  if !items
    ClosePopup()
    return
  endif

  if !winid
    winid = popup_create(items, {
      pos: 'botleft',
      line: &lines - &cmdheight,
      col: 1,
      fixed: true,
      maxheight: g:previewcmd.maxheight,
      filter: OnKeyPress,
    })
    win_execute(winid, 'set nowrap')
  else
    popup_settext(winid, items)
    popup_setoptions(winid, { cursorline: false })
  endif

  win_execute(winid, 'syntax clear')
  win_execute(winid, $'syntax match PMenuKind /{cmd}\c/')
  win_execute(winid, $'syntax case ignore')
  redraw
enddef

def ClosePopup()
  if !!winid
    popup_close(winid)
    winid = 0
    redraw
  endif
enddef

def SetupExCmd()
  if len(excmd) !=# 0
    return
  endif
  # get ex-commands from `:help index`
  var found_start = false
  for h in readfile($VIMRUNTIME .. '/doc/index.txt')
    if !found_start
      found_start = stridx(h, '*ex-cmd-index*') !=# -1
    elseif h =~# '^|:'
      # add `|:foo|...` -> `:foo  ...`
      excmd += [h[1 :]->substitute('|', '  ', '')]
    elseif !len(excmd)
    # NOP
    elseif h =~# '^\t'
      excmd[-1] ..= substitute(h, '^\s*', '', '')
    elseif !h
      break
    endif
  endfor
enddef

def SetupUserCmd()
  # reformat
  # Attribute Name     Args Address Complete    Definition
  # to
  # :Name \t\t Definition
  const lines = execute('command')->split("\n")
  const caption = lines[0]
  const namepos = 4
  const defpos = matchstrpos(caption, '\S\+$')[1]
  usercmd = lines[1 :]
    ->map((_, v) => $":{v[namepos :]->matchstr('^\S\+\s*')}\t\t{v[defpos : ]->substitute('^ \+', '', '')}")
enddef

def FilterCmd(commands: list<string>, cmd: string): list<string>
  var starts = []
  var contains = []
  var detail = []
  const head = $'^:{cmd}'
  const cont = $'^:\S\+{cmd}'
  for c in commands
    if c =~? head
      starts += [c]
    elseif c =~? cont
      contains += [c]
    elseif c =~? cmd
      detail += [c]
    endif
  endfor
  var filtered = starts + contains + detail
  if !g:previewcmd.fuzzy
    return filtered
  else
    var fuzzy = commands->matchfuzzy(cmd)
    filter(fuzzy, (_, v) => index(filtered, v) ==# -1)
    return filtered + fuzzy
  endif
enddef

def OnKeyPress(_: number, key: string): bool
  if key ==# "\<ESC>"
    ClosePopup()
    return true
  elseif key ==# "\<Tab>" || key ==# "\<C-n>"
    SelectCmd('j')
    return true
  elseif key ==# "\<S-Tab>" || key ==# "\<C-p>"
    SelectCmd('k')
    return true
  else
    return false
  endif
enddef

def SelectCmd(key: string)
  if popup_getoptions(winid).cursorline
    win_execute(winid, $'normal! {key}')
  else
    popup_setoptions(winid, { cursorline: true })
  endif
  win_execute(winid, 'w:selected = getline(".")')
  const cmd = getwinvar(winid, 'selected', '')->matchstr('^\S\+')[1 :]
  noautocmd setcmdline($'{!pos ? '' : getcmdline()[ : pos - 1]}{cmd}')
  redraw
enddef

