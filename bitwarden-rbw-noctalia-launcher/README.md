# Bitwarden RBW Noctalia Launcher

A Bitwarden/Vaultwarden password manager integration for Noctalia launcher using RBW (Rust Bitwarden CLI).

![Example Screenshot](preview.png)

## Features

- Unlock/lock RBW vault directly from the launcher
- Search and filter password entries by name, username, or website
- Copy passwords to clipboard with one click
- Display website favicons for visual identification
- Browse entries by folder with category filtering
- Different icons for different entry types (Login, Card, Note, Identity)
- Show website URLs in entry descriptions
- Integrated with Noctalia's launcher as a command provider

## Requirements

- [rbw](https://github.com/doy/rbw) - Rust Bitwarden CLI client
- `wl-copy` or `xclip` - Clipboard tools (wl-copy for Wayland, xclip for X11)
- `curl` - For downloading favicons (uses Google's favicon service)

## Installation

1. Ensure `rbw` and clipboard tools (`wl-copy` or `xclip`) are installed
2. Configure rbw: `rbw config set email your@email.com`
3. Enable the plugin in Noctalia settings
4. Unlock your vault: `rbw unlock` (or use `>rbw` in launcher)

## IPC Commands

### Toggle RBW Menu

```bash
qs -c noctalia-shell ipc call plugin:bitwarden-rbw-launcher toggle ""
```

Opens launcher with `>rbw` if closed, closes if already in RBW mode, or switches to RBW mode.

### Toggle with Domain Filter

```bash
qs -c noctalia-shell ipc call plugin:bitwarden-rbw-launcher toggle github.com
```

Opens launcher and searches for entries matching "github.com" (or any domain/text you specify).

### Open RBW Menu

```bash
qs -c noctalia-shell ipc call plugin:bitwarden-rbw-launcher open ""
```

Opens the launcher directly with the `>rbw` command prefix.

### Open with Domain Filter

```bash
qs -c noctalia-shell ipc call plugin:bitwarden-rbw-launcher open google
```

Opens launcher and searches for entries matching "google".

### Lock RBW Vault

```bash
qs -c noctalia-shell ipc call plugin:bitwarden-rbw-launcher lock
```

Locks the rbw agent.

### Unlock RBW Vault

```bash
qs -c noctalia-shell ipc call plugin:bitwarden-rbw-launcher unlock
```

Unlocks the rbw agent.

## Keybinding Examples

### Hyprland

```
# Toggle RBW launcher
bind = SUPER_SHIFT, P, exec, qs -c noctalia-shell ipc call plugin:bitwarden-rbw-launcher toggle ""

# Open with domain from clipboard
bind = SUPER_SHIFT_CTRL, P, exec, qs -c noctalia-shell ipc call plugin:bitwarden-rbw-launcher toggle $(wl-paste)
```

### Niri

```
binds {
    Mod+Shift+P { spawn "qs" "-c" "noctalia-shell" "ipc" "call" "plugin:bitwarden-rbw-launcher" "toggle"; }
}
```

### Qutebrowser Integration

Add to your qutebrowser config to open RBW launcher with the current host:

```python
config.bind('<Ctrl-Shift-p>', 'spawn qs -c noctalia-shell ipc call plugin:bitwarden-rbw-launcher toggle {url:host}')
```
