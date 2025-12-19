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
      initilized: true,
      delay: 100,
      fuzzy: true,
      enable: true,
      keymap_next: ["\<Tab>"],
      keymap_prev: ["\<S-Tab>"],
      keymap_close: ["\<Esc>", "\<C-y>"],
      keymap_end: ["\<C-e>"],
      keymap_top: [],
      popup_props: {},
    }->extend(get(g:, 'previewcmd', {}))
  endif
enddef

def Open(_: number)
  if mode() ==# 'c' && getcmdtype() ==# ':'
    bak = getcmdline()
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
      maxheight: 10,
      filter: OnKeyPress,
    }->extend(g:previewcmd.popup_props))
    win_execute(winid, 'set nowrap tabstop=8')
  else
    popup_settext(winid, items)
    popup_setoptions(winid, { cursorline: false })
  endif

  win_execute(winid, 'syntax clear')
  win_execute(winid, 'syntax case ignore')
  win_execute(winid, $'syntax match PMenuKind /{cmd}\c/')
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
    ClosePopup()
    return true
  elseif index(g:previewcmd.keymap_end, key) !=# -1
    setcmdline(bak)
    ClosePopup()
    return true
  elseif index(g:previewcmd.keymap_next, key) !=# -1
    SelectCmd('j')
    return true
  elseif index(g:previewcmd.keymap_prev, key) !=# -1
    SelectCmd('k')
    return true
  elseif index(g:previewcmd.keymap_top, key) !=# -1
    SelectCmd('gg', ' ')
    ClosePopup()
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

