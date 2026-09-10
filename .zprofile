#!/usr/bin/env zsh

typeset -gaU path
[[ -d $HOME/bin ]] && path=($HOME/bin $path)
[[ -d $HOME/.local/bin ]] && path=($HOME/.local/bin $path)
export PATH

export SHELL_SESSIONS_DISABLE=1
export EDITOR=nano
export VISUAL=zed
