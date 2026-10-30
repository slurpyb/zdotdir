#!/usr/bin/env zsh
# Real ZLE completion through a disposable pseudo-terminal, with no network tools.
emulate -LR zsh
setopt errexit nounset
export GHNEW_TEST_PROJECT=${0:A:h:h}
export GHNEW_TEST_ROOT=$(mktemp -d)
local sandbox=$GHNEW_TEST_ROOT
trap 'zpty -d ghnew-completion 2>/dev/null; /bin/rm -rf -- "$GHNEW_TEST_ROOT"' EXIT
mkdir -p "$sandbox/bin" "$sandbox/home" "$sandbox/work/source path"
for tool in gh git ssh; do
  print -r -- '#!/bin/zsh -f
print -r -- "$0 $*" >> "$GHNEW_TEST_ROOT/calls"
exit 99' > "$sandbox/bin/$tool"
  chmod +x "$sandbox/bin/$tool"
done
cat > "$sandbox/init.zsh" <<'INIT'
unset HISTFILE
bindkey -e
fpath=("$GHNEW_TEST_PROJECT/completions" "$GHNEW_TEST_PROJECT/functions" $fpath)
autoload -Uz compinit ghn
compinit -D
compdef _ghn ghn
capture_buffer() { print -r -- "$BUFFER" > "$GHNEW_TEST_ROOT/result"; }
zle -N capture_buffer
bindkey '^I' complete-word
bindkey '^X' capture_buffer
PS1='READY> '
cd "$GHNEW_TEST_ROOT/work"
print ready > "$GHNEW_TEST_ROOT/ready"
INIT
export PATH="$sandbox/bin" ZDOTDIR="$sandbox/home" GH_TOKEN=offline-test-not-a-token
rehash
[[ $(whence -p gh) == "$sandbox/bin/gh" ]] || exit 99
zmodload zsh/zpty
zmodload zsh/zselect
zpty -b ghnew-completion /bin/zsh -df
zpty -w ghnew-completion "source '$sandbox/init.zsh'"
local reply actual
wait_for_file() {
  local file=$1
  repeat 100; do
    [[ ! -s $file ]] || return 0
    if zpty -r -t ghnew-completion reply; then
      print -rn -- "$reply" >> "$sandbox/transcript"
    fi
    zselect -t 5 || true
  done
  print -ru2 -- "FAIL: completion timed out; transcript: $(<"$sandbox/transcript")"
  return 1
}
wait_for_file "$sandbox/ready"
local -a inputs expected
inputs=('ghn fsl/repo --no-rea' 'ghn sb repo --no-ig' 'ghn fsl/repo --source ./sou' 'ghn fs' 'ghn --username fs')
expected=('ghn fsl/repo --no-readme ' 'ghn sb repo --no-ignores ' 'ghn fsl/repo --source ./source\ path/' 'ghn fsl ' 'ghn --username fsl ')
local -i i
for (( i=1; i <= $#inputs; ++i )); do
  : > "$sandbox/result"
  zpty -w -n ghnew-completion $'\C-u'"$inputs[$i]"$'\t\C-x'
  wait_for_file "$sandbox/result"
  actual=$(<"$sandbox/result")
  [[ $actual == "$expected[$i]" ]] || {
    print -ru2 -- "FAIL: expected [$expected[$i]], got [$actual]"
    exit 1
  }
done
[[ ! -s $sandbox/calls ]] || { print -ru2 -- "FAIL: completion invoked a network tool: $(<"$sandbox/calls")"; exit 1; }
zpty -d ghnew-completion
print -- "PASS: $#inputs real ZLE completions; zero gh/git/ssh calls"
