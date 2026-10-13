# Australis command shell

The normal command shell is a userland program, `CommandShell.exec`. Its
source project is in this repository, but `program.hy` is currently empty.
The interactive `kmon>` shell running today is kernel-owned recovery
infrastructure; it is retained until the userland shell passes its boot tests.

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

| Userland shell built-in | External program in `/Bin` |
| --- | --- |
| `cd` | `cat.exec`, `ls.exec`, `pwd.exec` |
| `set`, `export`, `unset` | `version.exec`, `echo.exec` |
| `exit`, `help`, `history` | `clear.exec`, inspection tools |
| Later: `jobs`, `fg`, `bg` | Later: editing, process, and administration tools |

`cd` must change the shell's own working directory. A separate
`change-directory.exec` cannot change its parent shell's state. The
recovery shell may retain its built-in commands while their external
replacements are proved.

The userland shell will own tokenization, quote and escape handling, shell
variables, `PATH`, foreground launch and wait, and clear exit/fault reports.
The kernel will provide checked process, descriptor, filesystem, and terminal
mechanisms. The current recovery shell searches `PATH=/System:/Bin:/`; the
first userland shell should use `PATH=/Bin:/System`. Explicit
`run /path/program.exec` remains available during the transition.

## Completion gate

Build `CommandShell.exec` and the first external commands from source.
Over COM1 and USB keyboard, `cat /hello.txt`, `ls /`, and `version` must
resolve through `PATH`; serial and framebuffer output must agree. A bad
executable or nonzero exit must return to the prompt without leaking
descriptors, pages, mappings, or queued input. See
[userland Stage 2](../userland/README.md) for the full exit test.
