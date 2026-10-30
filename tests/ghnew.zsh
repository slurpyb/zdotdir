#!/usr/bin/env zsh
# Offline contract checks: real temporary Git repositories, executable gh stub.
emulate -LR zsh
setopt errexit nounset pipefail
[[ ${GHNEW_TRACE:-0} != 1 ]] || setopt xtrace
local project=${0:A:h:h} sandbox
sandbox=$(mktemp -d)
trap 'rc=$?; if (( ZSH_SUBSHELL == 0 )); then if (( rc )); then [[ ! -f "$sandbox/out" ]] || cat "$sandbox/out"; fi; rm -rf -- "$sandbox"; fi' EXIT
mkdir -p "$sandbox/bin" "$sandbox/work"
export GHNEW_LOG="$sandbox/gh.log" GHNEW_MODE=ok
# Exclude Homebrew (real gh) entirely, and invalidate credentials as a backstop.
export PATH="$sandbox/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export GH_TOKEN=offline-test-not-a-token GH_CONFIG_DIR="$sandbox/gh-config"
# Isolate user Git configuration and hooks from disposable repositories.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.invalid
cat > "$sandbox/bin/gh" <<'STUB'
#!/bin/zsh -f
print -r -- "${(j:|:)@}" >> "$GHNEW_LOG"
case "$1 $2" in
  'config get') print -r -- "${GHNEW_PROTOCOL:-https}" ;;
  'auth status') [[ $GHNEW_MODE != auth-fail ]] ;;
  'repo view') [[ $GHNEW_MODE == collision ]] ;;
  'repo create') [[ $GHNEW_MODE != create-fail ]] ;;
  *) exit 90 ;;
esac
STUB
chmod +x "$sandbox/bin/gh"
rehash
[[ $(whence -p gh) == "$sandbox/bin/gh" ]] || exit 99
fpath=("$project/functions" $fpath)
autoload -Uz ghn
local -i passed=0
check() { "$@" || { print -ru2 -- "FAIL: ${(j: :)@}"; exit 1; }; (( ++passed )); }
contains() { grep -Fq -- "$2" "$1"; }
absent() { ! grep -Fq -- "$2" "$1"; }
fails() { if ghn "$@" > "$sandbox/out" 2>&1; then print -ru2 -- "Unexpected success: $*"; return 1; fi; }
reset_log() { : > "$GHNEW_LOG"; }
cd "$sandbox/work"
ghn --help > "$sandbox/help"
check contains "$sandbox/help" 'Usage: ghn'
# Both short and full owners normalize before any external operation, in CLI/JSON.
for owner expected in fsl full-snack-lab sb slurpyb full-snack-lab full-snack-lab slurpyb slurpyb; do
  reset_log
  ghn "$owner" example --no-source --no-readme --no-ignores > "$sandbox/out" 2>&1
  check contains "$GHNEW_LOG" "repo|create|$expected/example|--private"
  ghn --json "{\"username\":\"$owner\",\"name\":\"json\",\"source\":false,\"readme\":false,\"ignores\":false}" > "$sandbox/out" 2>&1
  check contains "$GHNEW_LOG" "repo|create|$expected/json|--private"
done
reset_log
check fails other example --no-source
check fails --username other --name example --no-source
check fails --json '{"username":"other","name":"example","source":false}'
check test ! -s "$GHNEW_LOG"
autoload -Uz ghnew
ghnew sb compatibility --no-source --no-readme --no-ignores > "$sandbox/out" 2>&1
check contains "$GHNEW_LOG" 'repo|create|slurpyb/compatibility|--private'
check fails --name missing-owner --no-source
check fails full-snack-lab/demo --name other --no-source
check fails full-snack-lab demo extra --no-source
check fails full-snack-lab/ --no-source
check fails full-snack-lab/demo/extra --no-source
check fails full-snack-lab --json '{}'
ghn full-snack-lab/short --no-source --no-readme --no-ignores > "$sandbox/out" 2>&1
check contains "$GHNEW_LOG" 'repo|create|full-snack-lab/short|--private'
check contains "$sandbox/out" 'No local source attached; no files uploaded.'
ghn full-snack-lab two-words --no-source --no-readme --no-ignores > "$sandbox/out" 2>&1
check contains "$GHNEW_LOG" 'repo|create|full-snack-lab/two-words|--private'
check fails --json '{"username":"full-snack-lab","public":"false"}'
check fails --json '{"username":"full-snack-lab","extra":true}'
check fails --json '{"username":"full-snack-lab","name":"x","source":false,"public":false,"public":true}'
check contains "$sandbox/out" 'Duplicate JSON keys'
check fails --json '{"username":{"nested":[1]},"username":"full-snack-lab"}'
check contains "$sandbox/out" 'Duplicate JSON keys'
check fails --json '{"username":"full-snack-lab","ignores":["a","b"],"ignores":false}'
check contains "$sandbox/out" 'Duplicate JSON keys'
check fails --json '{"username":"full-snack-lab","source":null}'
check fails --json '{"username":"full-snack-lab"} {}'
check fails --json '{"username":"full-snack-lab","name":"x\u0000y"}'
check fails --json '{"username":"full-snack-lab"}' --no-source
check fails --username full-snack-lab --push --no-push
check fails --username full-snack-lab --name '../escape' --no-source
check fails --username full-snack-lab --name demo --no-source --push
check fails --username full-snack-lab --name demo --ignore $'bad\nentry' --no-source
reset_log
ghn --json '{"username":"full-snack-lab","name":"false-case","source":false,"public":false,"readme":false,"push":false,"ignores":false}' > "$sandbox/out" 2>&1
check contains "$GHNEW_LOG" 'repo|create|full-snack-lab/false-case|--private'
check test ! -e README.md
check test ! -e .gitignore
# Bare environment gets no Python/Node rules; custom patterns are literal data.
ghn --username full-snack-lab --name plain --no-source --no-readme > "$sandbox/out" 2>&1
check absent .gitignore 'node_modules/'
check absent .gitignore '__pycache__/'
ghn --json '{"username":"full-snack-lab","name":"custom","source":false,"readme":false,"ignores":["$(touch INJECTED)","custom/","custom/"]}' > "$sandbox/out" 2>&1
check test ! -e INJECTED
check contains .gitignore '$(touch INJECTED)'
check test "$(grep -Fc 'custom/' .gitignore)" = 1
rm .gitignore
# No repository (and an unborn repository) must not trigger source prompts.
ghn --username full-snack-lab --name no-repo --no-readme --no-ignores > "$sandbox/out" 2>&1
check contains "$GHNEW_LOG" 'repo|create|full-snack-lab/no-repo|--private'
mkdir "$sandbox/unborn"
git -C "$sandbox/unborn" init -q
cd "$sandbox/unborn"
ghn --username full-snack-lab --name unborn --no-readme --no-ignores > "$sandbox/out" 2>&1
check contains "$GHNEW_LOG" 'repo|create|full-snack-lab/unborn|--private'
check test -z "$(git remote)"
cd "$sandbox/work"
# Defaults, mixed environments, preservation and exact-entry deduplication.
touch uv.lock package.json
print -rn -- 'keep me' > README.md
print -rn -- '# original' > .gitignore
ghn --username full-snack-lab --name mixed --no-source > "$sandbox/out" 2>&1
check test "$(<README.md)" = 'keep me'
for entry in '.env*' .envrc node_modules/ __pycache__/ .venv/; do check contains .gitignore "$entry"; done
check contains .gitignore '# original'
cp .gitignore "$sandbox/ignore-before"
ghn --username full-snack-lab --name mixed-again --no-source > "$sandbox/out" 2>&1
check cmp .gitignore "$sandbox/ignore-before"
check absent .gitignore '.infisical.json'
check absent .gitignore '.python-version'
# CRLF entries compare equal, without rewriting the file.
awk '{printf "%s\r\n", $0}' .gitignore > "$sandbox/crlf"
cp "$sandbox/crlf" .gitignore
ghn --username full-snack-lab --name crlf --no-source > "$sandbox/out" 2>&1
check cmp .gitignore "$sandbox/crlf"
# Invalid ignore targets must be rejected before generating README.
rm README.md .gitignore
ln -s "$sandbox/crlf" .gitignore
check fails --username full-snack-lab --name symlink --no-source
check test ! -e README.md
rm .gitignore
mkdir .gitignore
check fails --username full-snack-lab --name directory --no-source
check test ! -e README.md
rmdir .gitignore
print preserved > README.md
# New README is local, and gh never receives --add-readme/--source/--push.
rm README.md
ghn --username full-snack-lab --name fresh --no-source > "$sandbox/out" 2>&1
check test "$(<README.md)" = '# fresh'
check contains "$sandbox/out" 'will NOT be included'
check absent "$GHNEW_LOG" '--add-readme'
check absent "$GHNEW_LOG" '--push'
# Explicit source containing spaces: Git root validation and origin ownership.
mkdir "$sandbox/source space"
git -C "$sandbox/source space" init -q
print original > "$sandbox/source space/file"
git -C "$sandbox/source space" add file
git -C "$sandbox/source space" commit -qm initial
mkdir "$sandbox/source space/nested"
GIT_DIR="$sandbox/source space/.git" check fails --username full-snack-lab --name override --no-source
check contains "$sandbox/out" 'Unset GIT_DIR'
check fails --username full-snack-lab --name nested --source "$sandbox/source space/nested" --no-readme --no-ignores
ghn --username full-snack-lab --name explicit --source "$sandbox/source space" --no-readme --no-ignores --no-push > "$sandbox/out" 2>&1
check test "$(git -C "$sandbox/source space" remote get-url origin)" = https://github.com/full-snack-lab/explicit.git
check fails --username full-snack-lab --name overwrite --source "$sandbox/source space" --no-readme --no-ignores
check test "$(git -C "$sandbox/source space" remote get-url origin)" = https://github.com/full-snack-lab/explicit.git
# Nested working directory never auto-selects its parent repository.
cd "$sandbox/source space/nested"
ghn --username full-snack-lab --name unrelated --no-readme --no-ignores > "$sandbox/out" 2>&1
check contains "$GHNEW_LOG" 'repo|create|full-snack-lab/unrelated|--private'
cd "$sandbox/work"
# Authentication and collisions stop before creating files or remote repositories.
rm README.md
for mode in auth-fail collision; do
  export GHNEW_MODE=$mode
  reset_log
  check fails --username full-snack-lab --name rejected --no-source
  check test ! -e README.md
  check absent "$GHNEW_LOG" 'repo|create'
done
export GHNEW_MODE=create-fail
check fails --username full-snack-lab --name failed --no-source
check contains "$sandbox/out" 'Local generated files remain'
check test -f README.md
export GHNEW_MODE=ok
# Stub only mutating Git boundaries for push and post-create recovery.
export GHNEW_REAL_GIT=$(whence -p git) GHNEW_GIT_MODE=push-fail
cat > "$sandbox/bin/git" <<'STUB'
#!/bin/zsh -f
if [[ ${3-} == push ]]; then
  print -r -- "git|${(j:|:)@}" >> "$GHNEW_LOG"
  print -r -- "ssh|${GIT_SSH_COMMAND-}" >> "$GHNEW_LOG"
  exit 1
fi
if [[ ${3-} == remote && ${4-} == add && $GHNEW_GIT_MODE == remote-fail ]]; then exit 1; fi
exec "$GHNEW_REAL_GIT" "$@"
STUB
chmod +x "$sandbox/bin/git"
rehash
command git -C "$sandbox/source space" remote remove origin
# Origin-like remote names are not origin; preserve them while adding origin.
for remote_name in origin-backup myorigin; do
  command git -C "$sandbox/source space" remote add "$remote_name" https://example.invalid/old.git
  ghn --username full-snack-lab --name similar --source "$sandbox/source space" --no-readme --no-ignores > "$sandbox/out" 2>&1
  check test "$(command git -C "$sandbox/source space" remote get-url "$remote_name")" = https://example.invalid/old.git
  check test "$(command git -C "$sandbox/source space" remote get-url origin)" = https://github.com/full-snack-lab/similar.git
  command git -C "$sandbox/source space" remote remove origin
  command git -C "$sandbox/source space" remote remove "$remote_name"
done
reset_log
check fails --username full-snack-lab --name public-push --public --source "$sandbox/source space" --no-readme --no-ignores --push
check contains "$GHNEW_LOG" 'repo|create|full-snack-lab/public-push|--public'
branch=$(command git -C "$sandbox/source space" symbolic-ref --short HEAD)
check contains "$GHNEW_LOG" "push|--no-follow-tags|--recurse-submodules=no|--set-upstream|origin|refs/heads/${branch}:refs/heads/${branch}"
check contains "$sandbox/out" 'PUBLICLY'
check contains "$sandbox/out" 'WAS CREATED and origin configured'
command git -C "$sandbox/source space" remote remove origin
export GHNEW_GIT_MODE=remote-fail
check fails --username full-snack-lab --name remote-fail --source "$sandbox/source space" --no-readme --no-ignores
check contains "$sandbox/out" 'WAS CREATED; remote setup failed'
export GHNEW_GIT_MODE=push-fail
# Follow gh protocol, including ordinary same-repository HTTPS -> SSH rewriting.
export GHNEW_PROTOCOL=ssh
ghn full-snack-lab/ssh --source "$sandbox/source space" --no-readme --no-ignores > "$sandbox/out" 2>&1
check test "$(command git -C "$sandbox/source space" remote get-url origin)" = git@github.com:full-snack-lab/ssh.git
command git -C "$sandbox/source space" remote remove origin
export GHNEW_PROTOCOL=https
command git -C "$sandbox/source space" config url.'git@github.com:'.insteadOf https://github.com/
ghn full-snack-lab/rewritten --source "$sandbox/source space" --no-readme --no-ignores > "$sandbox/out" 2>&1
check test "$(command git -C "$sandbox/source space" remote get-url --push origin)" = git@github.com:full-snack-lab/rewritten.git
command git -C "$sandbox/source space" remote remove origin
command git -C "$sandbox/source space" config --unset-all url.'git@github.com:'.insteadOf
# Reject other destinations before gh create, local generation, or remote setup.
command git -C "$sandbox/source space" config url.'https://example.invalid/'.insteadOf https://github.com/
reset_log
check fails full-snack-lab/unsafe --source "$sandbox/source space" --no-readme --no-ignores
check contains "$sandbox/out" 'nothing was created'
check absent "$GHNEW_LOG" 'repo|create'
check test -z "$(command git -C "$sandbox/source space" remote)"
command git -C "$sandbox/source space" config --unset-all url.'https://example.invalid/'.insteadOf
export GHNEW_PROTOCOL=invalid
reset_log
check fails full-snack-lab/bad-protocol --source "$sandbox/source space" --no-readme --no-ignores
check absent "$GHNEW_LOG" 'repo|create'
# First SSH option wins: overriding BatchMode=no must not permit prompting.
export GHNEW_PROTOCOL=ssh
reset_log
identity="$sandbox/key with spaces"
print fixture > "$identity"
GIT_SSH_COMMAND="ssh -F /dev/null -oBatchMode=no -i ${(q)identity}" \
  check fails full-snack-lab/batch --source "$sandbox/source space" --no-readme --no-ignores --push
check contains "$sandbox/out" 'WAS CREATED and origin configured, but push failed'
ssh_line=$(grep '^ssh|' "$GHNEW_LOG" | tail -1)
ssh_command=${ssh_line#ssh|}
ssh_args=("${(@Q)${(z)ssh_command}}")
ssh_config=$(command "${ssh_args[@]}" -G github.com 2>/dev/null)
print -r -- "$ssh_config" > "$sandbox/ssh-config"
check grep -Fxq -- 'batchmode yes' "$sandbox/ssh-config"
check grep -Fxq -- "identityfile $identity" "$sandbox/ssh-config"
# Git executes GIT_SSH_COMMAND via a shell; preserve that boundary as a regression.
/bin/sh -c "$ssh_command -G github.com" > "$sandbox/ssh-shell-config" 2>/dev/null
check grep -Fxq -- 'batchmode yes' "$sandbox/ssh-shell-config"
check grep -Fxq -- "identityfile $identity" "$sandbox/ssh-shell-config"
command git -C "$sandbox/source space" remote remove origin
GIT_SSH_COMMAND='ssh -i $HOME/key' \
  check fails full-snack-lab/custom-shell --source "$sandbox/source space" --no-readme --no-ignores --push
check contains "$sandbox/out" 'automatic SSH push requires an OpenSSH command'
print -- "PASS: $passed offline contract checks"
