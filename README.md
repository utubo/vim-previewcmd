# vim-previewcmd

Adds preview to Vim's command-line completion. Shows :help ex-cmd-index and :command output.

Inspired by https://github.com/vim/vim/issues/18843

<img width="638" height="358" alt="image" src="https://github.com/user-attachments/assets/74939aa9-50da-4b49-a783-d98baecb1f20" />

## Requirements

    Vim 9.1+ with +popupwin

## Installation

e.g.)

```sh
mkdir -p ~/.vim/pack/foo/opt
cd ~/.vim/pack/foo/opt
git clone https://github.com/utubo/vim-previewcmd
```

```vimscript
packadd vim-previewcmd
```

## Usage

Type `:` and start typing a command; a preview will appear as you type.

Default key mappings:
- `<Tab>` ... Previous command
- `<S-Tab>` ... Next command
- `<C-y>` ... Accept and close
- `<C-e>` ... End completion
- n/a ... Select first + space

## Configuration

See [doc/previewcmd.txt](doc/previewcmd.txt).

## License

[NYSL](https://www.kmonos.net/nysl/index.en.html)

