# Australis shell plan

## CLI Commands to require

| Built into SHELL.OS | Separate `.exec` |
| --- | --- |
| `cd` | `ls` |
| `exit` | `cat` |
| `help` | `edit` |
| `history` | `hexview` |
| `export` | `finfo` |
| `jobs` | `ps` |
| `fg` | `calc` |
| `bg` |  |

## Australis Boot pattern

### Normal Boot

```text
BOOTX64.EFI
     │
     ▼
KERNEL.BIN
     │
     ├── Initialise memory
     ├── Initialise interrupts
     ├── Initialise hardware
     ├── Mount root filesystem
     │
     ▼
ASTRALIS.OS
     │
     ├── LAUNCHER.OS
     ├── System Services
     │
     ▼
SHELL.OS
     │
     ▼
user@australis:/$
```

### Debugging Boot

```text
BOOTX64.EFI
     │
     ▼
KERNEL.BIN
     │
     ├── Initialise essential systems
     │
     ▼
    KMon
     │
     ▼
kmon> help
kmon> memmap
kmon> devices
kmon> continue
     │
     ▼
Continue Kernel Initialisation
     │
     ▼
ASTRALIS.OS
     │
     ▼
SHELL.OS
```
