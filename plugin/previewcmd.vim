vim9script

# Column positions in `:help ex-cmd-index` output
const actpos = 32

# Column positions in `:command` output
const cmdpos = 4
const defpos = 47

var winid = 0
var excmd = []
var usercmd = []
var pos = 0
var bak = ''

if !hlexists('PreviewCmd')
  hi default link PreviewCmd PMenu
  hi default link PreviewCmdMatch PMenuKind
endif

augroup previewcmd
  autocmd!
  autocmd CmdlineChanged * Silent(Main)
  autocmd CmdlineLeave * Silent(Close)
augroup END

def Silent(F: func)
  try
    F()
  catch
    echow 'previewcmd:' v:exception
    silent! Close()
  endtry
enddef

def Main()
  InitConfig()
  if !g:previewcmd.enable
    # NOP
  elseif !winid
    timer_start(g:previewcmd.delay, SafeOpen)
  else
    Update()
  endif
enddef

def InitConfig()
  if !exists('g:previewcmd.initilized')
    g:previewcmd = {
      initilized: true,
      delay: 100,
      fuzzy: true,
      enable: true,
      keymap_next: ["\<Tab>"],
      keymap_prev: ["\<S-Tab>"],
      keymap_close: ["\<C-y>"],
      keymap_end: ["\<C-e>"],
      keymap_top: [],
      popup_args: {},
    }->extend(get(g:, 'previewcmd', {}))
  endif
enddef

def SafeOpen(_: number)
  Silent(Open)
enddef

def Open()
  if mode() ==# 'c' && getcmdtype() ==# ':'
    bak = getcmdline()
    SetupExCmd()
    SetupUserCmd()
    Update()
  endif
enddef

def Update()
  if !IsValid()
    Close()
    return
  endif

  const cmd = getcmdline()->matchstr('[a-zA-Z][a-zA-Z0-9_/]*$')
  if !cmd
    Close()
    return
  endif

  pos = getcmdline()->len() - cmd->len()

  const items = (excmd + usercmd)->FilterCmd(cmd)
  if !items
    Close()
    return
  endif

  if !winid
    winid = popup_create(items, {
      pos: 'botleft',
      line: &lines - &cmdheight,
      col: 1,
      fixed: true,
      maxheight: 10,
      filter: OnKeyPress,
      heightlight: 'PreviewCmd',
    }->extend(g:previewcmd.popup_args))
    win_execute(winid, 'set nowrap tabstop=8')
  else
    popup_settext(winid, items)
    popup_setoptions(winid, { cursorline: false })
  endif

  win_execute(winid, 'syntax clear')
  win_execute(winid, 'syntax case ignore')
  win_execute(winid, $'syntax match PreviewCmdMatch /{cmd}\c/')
  redraw
enddef

def IsValid(): bool
  const c = getcmdline()
  # e.g. `s//`
  if c =~# '/'
    return false
  endif
  # no-args
  if c !~# ' '
    return true
  endif
  # tab, split, vsplit
  const a = getcmdline()->split(' ')
  if len(a) !=# 2 || len(a[0]) < 2
    return false
  endif
  if a[0] ==# 'tab'
    return true
  endif
  for d in ['split', 'vsplit']
    if stridx(d, a[0]) ==# 0 && len(a[0]) <= len(d)
      return true
    endif
  endfor
  return false
enddef

def Close()
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
  # :Name                           Definition
  const lines = execute('command')->split("\n")
  usercmd = lines[1 :]
    ->map((_, v) => {
        const c = v[cmdpos :]->matchstr('^\S\+')
        const d = v[defpos :]->matchstr('\S.*')
        return $':{c}{repeat(' ', actpos - len(c) - 3)}  {d}'
      })
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
  if index(g:previewcmd.keymap_close, key) !=# -1
    Close()
    return true
  elseif index(g:previewcmd.keymap_end, key) !=# -1
    setcmdline(bak)
    Close()
    return true
  elseif index(g:previewcmd.keymap_next, key) !=# -1
    SelectCmd('j')
    return true
  elseif index(g:previewcmd.keymap_prev, key) !=# -1
    SelectCmd('k')
    return true
  elseif index(g:previewcmd.keymap_top, key) !=# -1
    SelectCmd('gg', ' ')
    Close()
    return true
  else
    return false
  endif
enddef

def SelectCmd(key: string, addchar = '')
  if popup_getoptions(winid).cursorline
    win_execute(winid, $'normal! {key}')
  else
    popup_setoptions(winid, { cursorline: true })
  endif
  const v = 'previewcmd_selected'
  win_execute(winid, $'w:{v} = getline(".")')
  const cmd = getwinvar(winid, v, '')->matchstr('^\S\+')[1 :]
  noautocmd setcmdline($'{!pos ? '' : getcmdline()[ : pos - 1]}{cmd}{addchar}')
  redraw
enddef

