# Changelog

Significant changes to this Zsh configuration are documented here.

## 2026-08-27 — Migrate the editor stack to z1 v3

### Added

- Installed and activated `zsh-patina` 1.10.0 on macOS and Ubuntu for command-line syntax highlighting.
- Added `~/.local/bin` to login-shell `PATH`, making user-local tools available to interactive and non-interactive Zsh sessions.
- Adopted z1 v3 functionality, including:
  - Fish-style directory history with `prevd` and `nextd`.
  - Alt-Left and Alt-Right directory navigation on an empty command line.
  - Improved Home and End handling.
  - Cursor-shape changes between vi insert and command modes.
  - Ctrl-X Ctrl-X completion from history.
  - Ctrl-X Ctrl-C clipboard copying.
  - `mkcd` and `mktmpcd` helpers.
  - Native clipboard portability and terminal key-sequence handling.
  - Hidden-file matching through `glob_dots`.

### Changed

- Replaced `zsh-users/zsh-autosuggestions` with z1's native autosuggester.
  - History-based suggestions and the existing `fg=242` appearance are preserved.
  - Right Arrow, Ctrl-F, and Ctrl-E accept a complete suggestion; Alt-F accepts one word.
  - The new implementation uses `POSTDISPLAY` instead of wrapping every ZLE widget.
- Replaced `fast-syntax-highlighting` with `zsh-patina`.
  - Invalid commands are highlighted in red.
  - Existing files and directories are underlined.
  - Highlighting colors and classification may differ from the previous implementation.
- Replaced `zsh-history-substring-search` with z1's native history search.
  - Up and Down retain substring search.
  - Multiline navigation, match highlighting, and restoration of the originally typed line are improved.
- Preserved vi keybindings, Fish-like global alias expansion, Alt-Space behavior, dot expansion, the rapid prompt, Antidote, `fzf-tab`, completions, SQLite history, `conf.d`, and machine-local configuration.

### Removed

- Removed the superseded `zsh-users/zsh-autosuggestions` plugin and its configuration.
- Removed the incompatible `fast-syntax-highlighting` plugin.
- Removed the superseded `zsh-history-substring-search` plugin and `bindkey-hss` helper.
- Removed the temporary z1 v2 compatibility pin.
- Removed unused advanced autosuggestion capabilities, including completion-based strategies and autosuggestion enable/disable widgets.
- Removed FSH-specific command chromas and theming support; no custom FSH configuration was in use.

### Fixed

- Fixed recursive ZLE widget wrapping on Ubuntu that caused `maximum nested function level reached` after every command.
- Restricted the machine-local configuration loader to `*.zsh`, preventing `glob_dots` from treating `.gitignore` as a shell script.

### Compatibility notes

- z1's native autosuggester requires Zsh 5.9; both current machines meet this requirement.
- Ctrl-P/Ctrl-N and vi-command-mode `k`/`j` are no longer explicitly mapped to substring search. Arrow Up and Down continue to provide substring search.
- `zsh-patina` runs a small shared background daemon.
