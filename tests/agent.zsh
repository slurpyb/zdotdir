#!/usr/bin/env zsh
# Run with: zsh -f ~/.config/zsh/tests/agent.zsh
# All projects and executables below are disposable. No network calls.
emulate -LR zsh
setopt errexit
fpath=("${0:A:h:h}/functions" $fpath)
autoload -Uz agent
() {
local_root=$(mktemp -d "${TMPDIR:-/tmp}/agent-tests.XXXXXXXX")
local_root="${local_root:A}"
trap 'rm -rf -- "$local_root"' EXIT
mkdir -p "$local_root/project" "$local_root/outside" "$local_root/bin"
cd "$local_root/project"
PLUGINS="$local_root/plugins"
mkdir -p "$PLUGINS/base" "$PLUGINS/lang/skills/first/support" "$PLUGINS/lang/skills/second"
print -r -- $'---\nname: first\ndescription: first test skill\n---\nFIRST INSTRUCTIONS' > "$PLUGINS/lang/skills/first/SKILL.md"
print -r -- $'---\nname: second\ndescription: second test skill\n---\nSECOND INSTRUCTIONS' > "$PLUGINS/lang/skills/second/SKILL.md"
print -r -- 'supporting material' > "$PLUGINS/lang/skills/first/support/guide.md"
print -r -- 'CONTEXT DATA' > "$local_root/outside/context with spaces.csv"
print -r -- 'REFERENCE DATA' > "$local_root/outside/ref with spaces.md"
print -r -- 'SYSTEM FILE' > "$local_root/outside/system.md"
print -r -- 'ORIGINAL PROJECT INSTRUCTIONS' > AGENTS.md
export TEST_LOG="$local_root/rosie.log"
export TEST_ROSIE_MODE=normal
export TEST_ESCAPE="$local_root/outside/ref with spaces.md"

fail() { print -u2 -r -- "FAIL: $*"; exit 1; }
check() { [[ "$1" == "$2" ]] || fail "$3: expected ${(qqq)2}, got ${(qqq)1}"; }
pass() { print -r -- "PASS: $*"; }
typeset -a captured
typeset -i calls=0
pi() { captured=("$@"); (( ++calls )); return 0; }

agent --add base,lang -s first,second
check "${(j:|:)captured}" "--model|openai/gpt-6-astra|--thinking|medium|--extension|$PLUGINS/base|--extension|$PLUGINS/lang|--skill|$PLUGINS/lang/skills/first/SKILL.md|--skill|$PLUGINS/lang/skills/second/SKILL.md" 'resource argument boundaries'
pass 'first invocation; comma plugin and skill loading'

agent --add base --add lang -s first -w first,second --sol --max --bare -t read,bash 'task with spaces'
[[ "${(j:|:)captured}" == *'--model|openai/gpt-6-sol|--thinking|max'* ]] || fail shortcuts
[[ "${(j:|:)captured}" == *'--no-extensions|--no-skills|-t|read,bash'* ]] || fail 'native tools'
check "${captured[-1]}" 'task with spaces' 'prompt spaces'
skill_count=0
for flag in "${captured[@]}"; do
    [[ "$flag" != --skill ]] || (( ++skill_count ))
done
check "$skill_count" 2 'skill dedupe'
pass 'repeated add; shortcuts; bare; native -t; dedupe'

agent --with first -w second --context "$local_root/outside/context with spaces.csv" -l 'Use for DATA' --reference "$local_root/outside/ref with spaces.md" --label 'Read when X [or Z]' 'USER REQUEST'
body="$captured[-1]"
[[ "$body" == '<skill>'*'FIRST INSTRUCTIONS'*'USER REQUEST'*'CONTEXT DATA'*'References (read when relevant):'* ]] || fail 'prompt ordering'
[[ "$body" != *'SECOND INSTRUCTIONS'* ]] || fail '-w invoked skill body'
[[ "$body" != *'description: first test skill'* ]] || fail 'frontmatter not stripped'
(( ! ${captured[(Ie)-p]} )) || fail '--with forced print'
[[ "$body" == *'Read when X \[or Z\]'* ]] || fail 'label escaping'
files=(.agents/references/agent/*/'ref with spaces.md'(N))
check "${#files}" 1 'external file copied'
check "$(<"$files[1]")" 'REFERENCE DATA' 'copy content'
check "$(<AGENTS.md)" 'ORIGINAL PROJECT INSTRUCTIONS' 'ephemeral project isolation'
pass 'with loads and invokes; context and reference order; spaces; project isolation'

agent --with first,second 'TASK'
[[ "$captured[-1]" == *'FIRST INSTRUCTIONS'*'SECOND INSTRUCTIONS'*'TASK' ]] || fail 'multiple with order'
agent --context "$local_root/outside/context with spaces.csv" '@image.png' 'TASK'
(( ${captured[(Ie)@image.png]} )) || fail 'native image attachment preserved'
pass 'multiple invoked skills; native attachment passthrough'

agent --system "$local_root/outside/system.md" ---system 'INLINE SYSTEM' -- 'literal --add value'
check "$captured[-3]" $'SYSTEM FILE\nINLINE SYSTEM' 'system concatenation'
check "$captured[-1]" 'literal --add value' 'separator'
pass 'system file plus inline; -- terminator'

agent --reference "$PLUGINS/lang/skills/first/SKILL.md" -l 'Read for first skill' 'TASK'
files=(.agents/references/agent/*/support/guide.md(N))
check "${#files}" 1 'local skill support copied'
pass 'local skill reference retains supporting files'

before=$calls
if agent --reference "$local_root/outside/ref with spaces.md" 2>/dev/null; then fail 'missing label accepted'; fi
if agent --context https://example.invalid/data 2>/dev/null; then fail 'remote context accepted'; fi
printf '\x00\x01binary' > "$local_root/outside/movie.bin"
if agent --context "$local_root/outside/movie.bin" 2>/dev/null; then fail 'binary context accepted'; fi
if agent --add missing 2>/dev/null; then fail 'unknown plugin accepted'; fi
if agent -s missing 2>/dev/null; then fail 'unknown skill accepted'; fi
if agent --add base,,lang 2>/dev/null; then fail 'empty comma entry accepted'; fi
if agent --system ./missing.txt 2>/dev/null; then fail 'missing system file accepted'; fi
check "$calls" "$before" 'invalid requests must not start pi'
pass 'invalid requests fail before pi'

mkdir -p "$PLUGINS/other/skills/first"
cp "$PLUGINS/lang/skills/first/SKILL.md" "$PLUGINS/other/skills/first/SKILL.md"
if agent -s first 2>/dev/null; then fail 'ambiguous skill accepted'; fi
agent -s "$PLUGINS/lang/skills/first/SKILL.md"
pass 'ambiguous names require explicit paths'

# Model Rosies documented disk/argv boundary, not its implementation.
print -r -- '#!/bin/zsh
print -r -- "$PWD|$*" >> "$TEST_LOG"
[[ "$TEST_ROSIE_MODE" != fail ]] || exit 9
[[ "$TEST_ROSIE_MODE" != empty ]] || exit 0
shift
source="$1"; shift
selected=""; mode=skill
while (( $# )); do
    case "$1" in
        --ref) mode=ref; shift ;;
        --skill) selected="$2"; shift 2 ;;
        --agent) shift 2 ;;
        --yes|--npm) shift ;;
        *) selected="$1"; shift ;;
    esac
done
if [[ "$mode" == ref ]]; then
    directory=".agents/references/${source//\//-}${selected:+-$selected}"
    mkdir -p "$directory"
    print -r -- "REMOTE REFERENCE" > "$directory/REFERENCE.md"
    print -r -- "${directory:t} $source${selected:+#$selected} main deadbeef timestamp auto ref" >> .agents/rosie.lock
    print -r -- "ROSIE PROJECT INDEX" >> AGENTS.md
else
    directory=".agents/skills/$selected"
    mkdir -p "$directory/support"
    print -r -- "REMOTE SKILL" > "$directory/SKILL.md"
    print -r -- "REMOTE SUPPORT" > "$directory/support/guide.md"
    [[ "$TEST_ROSIE_MODE" != escape ]] || ln -s "$TEST_ESCAPE" "$directory/leak.md"
    if [[ "$TEST_ROSIE_MODE" == nestedescape ]]; then
        mkdir -p payload
        ln -s "$PWD/payload" "$directory/assets"
        ln -s "$TEST_ESCAPE" payload/leak.md
    fi
fi
' > "$local_root/bin/rosie"
chmod +x "$local_root/bin/rosie"
path=("$local_root/bin" $path)

agent --ref github.com/acme/skills,other/repo -s first,second 'TASK'
log="$(<"$TEST_LOG")"
[[ "$log" == *"$PWD|install acme/skills --ref --skill first --agent pi --yes"* ]] || fail 'ref normalization/scope'
[[ "$log" == *"$PWD|install other/repo --ref --skill second --agent pi --yes"* ]] || fail 'multi ref selection'
log_lines=("${(@f)log}")
check "${#log_lines}" 4 'one rosie call per source/skill'
pass 'ref delegates each selected remote skill directly in project'

print -r -- 'ORIGINAL PROJECT INSTRUCTIONS' > AGENTS.md
: > "$TEST_LOG"
agent --reference acme/skills -s first,second -l 'Read for skill guidance' 'TASK'
log="$(<"$TEST_LOG")"
[[ "$log" != *"$PWD|"* ]] || fail 'ephemeral Rosie ran in real project'
[[ "$log" == *'install acme/skills first --agent pi --yes'* ]] || fail 'full remote skill installation'
[[ "$captured[-1]" == *'Read for skill guidance'*'SKILL.md'* ]] || fail 'remote reference link'
files=(.agents/references/agent/*/support/guide.md(N))
check "${#files}" 3 'remote support copied before staging cleanup'
check "$(<AGENTS.md)" 'ORIGINAL PROJECT INSTRUCTIONS' 'remote project isolation'
pass 'remote skill staging; selections; support files; project isolation'

agent --reference acme/docs -l 'Read for repository guidance'
[[ "$captured[-1]" == *'REFERENCE.md'* ]] || fail 'Rosie REFERENCE.md layout'
check "$(<AGENTS.md)" 'ORIGINAL PROJECT INSTRUCTIONS' 'readme project isolation'
pass 'remote repository reference entry recognized'

before=$calls
for TEST_ROSIE_MODE in fail empty escape nestedescape; do
    if agent --reference acme/skills -s first -l 'Read this' 2>/dev/null; then fail "Rosie $TEST_ROSIE_MODE accepted"; fi
done
TEST_ROSIE_MODE=normal
check "$calls" "$before" 'failed remote preparation must not start pi'
pass 'Rosie failures, empty installs and direct/nested escaping symlinks stop launch'

before=$calls
TEST_ROSIE_MODE=empty
if agent --ref acme/absent 2>/dev/null; then fail 'empty --ref accepted'; fi
check "$calls" "$before" 'empty --ref launched pi'
TEST_ROSIE_MODE=normal
: > "$TEST_LOG"
if agent --reference ./missing.md -l 'Read this' 2>/dev/null; then fail 'missing local file accepted'; fi
[[ ! -s "$TEST_LOG" ]] || fail 'missing ./path mistaken for remote repo'
pass 'direct ref checked against Rosie lock; missing explicit local path stays local'

# References are links, not inline context: binary documents must be copied.
printf '%%PDF-1.7\n\0\n' > "$local_root/outside/document.pdf"
agent --reference "$local_root/outside/document.pdf" -l 'Read the PDF for layout'
files=(.agents/references/agent/*/document.pdf(N))
check "${#files}" 1 'PDF reference copied'
cmp "$local_root/outside/document.pdf" "$files[1]" || fail 'PDF bytes changed'
print -r -- '#!/bin/zsh
while (( $# )); do
    if [[ "$1" == --output ]]; then
        cp "$TEST_PDF" "$2"
        exit
    fi
    shift
done
exit 2
' > "$local_root/bin/curl"
chmod +x "$local_root/bin/curl"
rehash
export TEST_PDF="$local_root/outside/document.pdf"
agent --reference https://example.invalid/document.pdf -l 'Read the PDF for layout'
files=(.agents/references/agent/*/document.pdf(N))
check "${#files}" 2 'downloaded PDF reference copied'
pass 'local and downloaded binary references accepted without text decoding'

print -r -- 'ALL ZSH CHECKS PASSED'
}
