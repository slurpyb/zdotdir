# ZDOTDIR Update History

## August 27, 2026 — Seegson Toolchain Update Released

An update to JavaScript toolchain discovery has been released. The specific
changes include:

### Environment

- Added `~/.local/share/fnm` to the shared Zsh path when present.
- Added `~/.bun/bin` to the shared Zsh path when present.
- Added `BUN_INSTALL` with the standard `~/.bun` installation location.
- Added `~/bin` to login-shell paths alongside `~/.local/bin`.
- Enabled the existing Zsh-native `fnm` initialization on machines where `fnm`
  is installed.
- Retained the existing Zsh-native `direnv` integration without loading the
  Bash-specific Paleo Hero toolchain script.

## August 27, 2026 — Post-Pull Update Released

An update to ZDOTDIR maintenance has been released. The specific changes
include:

### Updates

- Added the `zdot-update` command to pull changes with fast-forward-only safety.
- Added an operating-system-aware post-pull check for macOS and Linux.
- Added validation of the root `.zshenv`, machine-local directories, shell
  dependencies, and Zsh syntax after each update.
- Added Homebrew package guidance on macOS and apt package guidance on Ubuntu
  and Debian when dependencies are missing.
- Existing `.zshenv` files with unexpected contents are reported and left
  unchanged.
- Antidote plugins and privileged packages remain unchanged unless updated
  separately.

## August 27, 2026 — Z1 v3 Update Released

An update to the ZDOTDIR shell environment has been released. The update will
be applied the next time Zsh is started after pulling the latest files.

The specific changes include:

### Z1

- Updated Z1 to version 3.0.0.
- Removed the temporary Z1 v2 compatibility lock.
- Added native history-based command suggestions.
- Added improved multi-line history navigation.
- Added highlighting of the matching text during history searches.
- Added restoration of the original command after searching down past the
  newest history match.
- Added Fish-style directory history with `prevd` and `nextd`.
- Added Alt-Left and Alt-Right navigation through directory history when the
  command line is empty.
- Improved Home and End key handling.
- Added cursor shape changes for Vi insert and command modes.
- Added Ctrl-X Ctrl-X completion from command history.
- Added Ctrl-X Ctrl-C clipboard copying.
- Added the `mkcd` and `mktmpcd` commands.
- Improved terminal key sequence and clipboard support.
- Hidden files are now included in normal glob matching.

### Command Suggestions

- Replaced `zsh-users/zsh-autosuggestions` with the built-in Z1 suggestion
  system.
- Command suggestions retain their previous `fg=242` color.
- Right Arrow, Ctrl-F, and Ctrl-E accept the complete suggestion.
- Alt-F accepts the next suggested word.
- Suggestions are now displayed without repeatedly wrapping editor widgets.
- Removed unused completion-based suggestion strategies.
- Removed unused suggestion enable, disable, and toggle widgets.

### Syntax Highlighting

- Replaced `fast-syntax-highlighting` with `zsh-patina` 1.10.0.
- Invalid commands are now displayed in red.
- Existing files and directories are now underlined.
- Improved command-line highlighting performance using a shared background
  service.
- Removed unused FSH command chromas and theme support.
- Syntax colors may differ from previous versions.

### History

- Replaced `zsh-history-substring-search` with Z1's built-in history search.
- Up Arrow and Down Arrow continue to search for commands containing the text
  already entered.
- Removed the obsolete `bindkey-hss` helper.
- Ctrl-P, Ctrl-N, and Vi command-mode `k` and `j` are no longer explicitly
  assigned to substring search and now use their standard Zsh behavior.

### Fixes

- Fixed a recursive editor widget condition that caused `maximum nested
  function level reached` to appear after every command on Ubuntu.
- Fixed machine-local startup attempting to execute `.gitignore` after hidden
  file globbing was enabled.
- Added `~/.local/bin` to the login shell path.
- Improved detection of optional Node tooling on machines without `fnm`.

### General

- Installed `zsh-patina` on macOS and Ubuntu.
- Retained Vi keybindings, Fish-style alias expansion, Alt-Space behavior, dot
  expansion, Rapid Prompt, Antidote, `fzf-tab`, completions, SQLite history,
  `conf.d`, and machine-local configuration support.
- Z1 command suggestions now require Zsh 5.9 or later.
