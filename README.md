# Australis command shell

The normal command shell is the userland program `CommandShell.exec`. It
parses commands, launches `/System/Bin/*.exec` children with arguments, and keeps
working-directory and history state. Normal boot starts it through
`System.exec`; KMon can also launch it with
`run /System/Core/CommandShell.exec`. Run `make test-userland-shell-preview`
for hosted input and launch checks, or `make test-userland-essentials` for
AHCI/NVMe QEMU checks. The interactive `kmon>` shell remains kernel-owned
recovery infrastructure.

The boot order and component names follow [the architecture](../README.md)
and [the active plan](../../PLAN.md):

```text
BOOTX64.EFI -> KERNEL.BIN -> /System/Core/System.exec (PID 1)
                                      -> CommandShell.exec
```

A failed root mount, missing or invalid PID 1, or an explicit recovery boot
must reach the kernel monitor (KMon) without needing this executable. The
separate [rescue project](../rescue/README.md) may provide extra tools after a
valid volume is mounted. The older names `ASTRALIS.OS` and `SHELL.OS` are
not the selected executable names for this route.

## Command ownership

| Userland shell built-in | External program in `/System/Bin` |
| --- | --- |
| `cd`, `pwd` | `cat.exec`, `ls.exec`, `echo.exec` |
| `exit`, `help`, `history`, `path` | `clear.exec`, `tree.exec`, file mutation tools |
| `set`, `export`, `unset` | `version.exec`, inspection tools |
| Later: `jobs`, `fg`, `bg` | `edit.exec`, `hexedit.exec`; later process tools |

`cd` must change the shell's own working directory. A separate
`change-directory.exec` cannot change its parent shell's state. The
recovery shell may retain its built-in commands while their external
replacements are proved.

The userland shell owns tokenization, quote and escape handling, a current
directory, foreground launch and wait, and exit/fault reports. `path` displays
or changes its session-local, colon-separated search path. Every directory
must be absolute and already exist; the default is `/System/Bin`.
The kernel provides checked process, descriptor, filesystem, and terminal
mechanisms. The recovery shell searches `PATH=/System/Bin:/System:/`. The
userland shell accepts `run /path/program.exec` for an explicit executable.
`set NAME VALUE` stores a shell-local value, `export NAME` passes it to child
programs, and `unset NAME` removes it. `PATH` and the current directory are
copied into each child start record.

`edit /data/note.txt` opens any file as text without a type check. It uses a
terminal screen with arrow, Home, End, Backspace, Delete, and Enter editing.
`hexedit /data/file` shows hex and ASCII bytes; type two hex digits to change
a byte or append one at EOF. Its arrows, Home, End, and Delete move or remove
bytes. Both editors use Ctrl-S to save, Ctrl-O to save under another path, and
Ctrl-X to exit with a save prompt when changes are pending. They report a
read-only source and offer Save As under writable `/data`. Both limit files to
4096 bytes; the boot root and `/System/Bin` remain read-only.
In either editor's Save As prompt, Ctrl-G cancels without changing the path.

## Completion gate

Build `CommandShell.exec` and the first external commands from source.
Over COM1 and USB keyboard, `cat /hello.txt`, `ls /`, and `version` must
resolve through `PATH`; serial and framebuffer output must agree. A bad
executable or nonzero exit must return to the prompt without leaking
descriptors, pages, mappings, or queued input. See
[userland Stage 2](../userland/README.md) for the full exit test.
The gate passes on AHCI and NVMe. Read-only and failed launches reclaim
managed pages at the next shell input; filesystem mutation retains pages
that may be referenced by HyFS 2 metadata.
