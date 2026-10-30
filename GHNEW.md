# `ghn`: create a GitHub repository

An autoloaded Zsh function in `functions/ghn`; normal `gh` commands are unchanged.
`ghnew` remains a compatibility alias for `ghn`.
Requires Git and GitHub CLI. JSON input additionally uses the already-installed
`jq` (checked with 1.7.1). No Python or Node runtime is used.

Open a new shell, or load it now:

```zsh
autoload -Uz ghn  # functions/ is already on this configuration's fpath
ghn --help
```

## Owners

Only these two GitHub owners are accepted, in positional arguments, `--username`,
and JSON `username`. Shortcuts are expanded before any GitHub operation:

| Shortcut | Full name | Account |
| --- | --- | --- |
| `fsl` | `full-snack-lab` | Organization |
| `sb` | `slurpyb` | Personal |

Both shortcuts and full names work. Other owners fail before any file writes or
GitHub calls. Tab completes the supported owners.

## Everyday use

From a committed Git root with no remotes:

```zsh
ghn fsl example --push
```

Press **Enter** to accept the current repository as the source. That creates a
private GitHub repository, preserves/generates local README and ignore files,
configures `origin` using your GitHub CLI protocol preference, and pushes the
already-committed branch. Generated files are explicitly reported as uncommitted.
Without `--push`, it only connects the remote and prints the command to push later.

Use `ghn sb` for a generated name in your personal account, or `ghn fsl` for
a generated name in the organization. `ghn fsl/example` also works. Tab completes
options and `--source` directories without making any GitHub requests. The owner
is always explicit; no account or organization is silently chosen for you.

## Examples

```zsh
# Private repository, current Git root as source, push current committed branch:
ghn full-snack-lab/example-repo-name --source . --push

# Suggest a three-word name; confirm, replace it, or enter ! to cancel:
ghn sb --no-source

# Public, but no push:
ghn full-snack-lab/public-example --public --no-source

# Custom ignores replace automatic defaults (repeat --ignore):
ghn full-snack-lab/example --no-source \
  --ignore '.env*' --ignore '.envrc' --ignore 'scratch/'

# Exact JSON invocation; explicit false stays false:
ghn --json '{"username":"full-snack-lab","name":"example","source":false,"public":false,"readme":true,"push":false,"ignores":false}'

# Read exactly one JSON object from stdin:
printf '%s\n' '{"username":"full-snack-lab","name":"example","source":".","push":false}' |
  ghn --json -
```

`--json OBJECT` and `--json -` must be used alone, not mixed with ordinary options.
JSON is parsed as data with jq, never evaluated as shell code. Output remains
human-readable (success includes the repository URL); use the exit status for
success/failure. A future `--output json` could expose the created URL and partial
success state, but is deliberately not part of this interface.

## Parameters

| Parameter | CLI | JSON type | Omitted behavior |
| --- | --- | --- | --- |
| `username` | positional `OWNER` or `--username OWNER` | string | Required; fsl/full-snack-lab or sb/slurpyb only |
| `name` | positional `/NAME` or `NAME`, or `--name NAME` | string | Generate three words and ask for confirmation |
| `public` | `--public`, `--no-public` | boolean | `false` (private) |
| `source` | `--source PATH`, `--no-source` | string or `false` | Offer current directory only if it is the exact Git root, has a commit, and has no remotes |
| `readme` | `--readme`, `--no-readme` | boolean | `true` |
| `push` | `--push`, `--no-push` | boolean | `false`; always opt-in |
| `ignores` | repeated `--ignore ENTRY`, `--no-ignores` | array of strings or `false` | Environment-aware defaults |

The original `--username OWNER --name NAME` spelling remains available. Do not mix
positional naming with `--username`/`--name`: use one naming form consistently.

Unknown or duplicate keys, nulls, wrong types, empty/control-containing JSON strings, multiple
JSON values, conflicting/repeated CLI options (except `--ignore`), and malformed
JSON are errors. `ignores: []` is an empty custom list, not automatic generation.
Custom entries replace the generated list, **not** the existing file. Shell-quote
ignore patterns to prevent expansion. A source path literally named `false` is a
string; JSON `false` means no source.

Names allow 1–100 ASCII letters, digits, dots, underscores and hyphens, excluding
`.` and `..` and the confusing `.git` suffix. Accessible existing repositories
are rejected. Creation is authoritative if the availability lookup fails (which
could mean an inaccessible private repository or a network failure). No existing
repository is adopted on failure, and no name is silently changed.

## Sources, files, and pushing

- The source suggestion defaults to **Yes** on Enter. Invocation in any nested
  directory does **not** automatically select a parent repository. Explicit
  sources must also be exact, non-bare repository roots; worktrees are supported.
- `--no-source` / `"source": false` explicitly declines auto-detection, including
  in automation. Without a usable `/dev/tty`, a required prompt fails rather than
  approving a choice. Provide a name and an explicit source decision unattended.
- README and ignores default to the **current directory**, not an implicit Git
  root. If a selected source differs and generation is enabled, choose `c` for
  current directory or `s` for source. There is deliberately no silent default.
  For unattended use, `cd` to the source first, or disable both generators.
- Existing README content is preserved. A missing README gets `# FINAL-NAME`.
  Existing `.gitignore` content is preserved, exact duplicate entries are skipped,
  and symlink/non-regular `.gitignore` files are refused. New rules may require
  reviewing earlier negation rules in a hand-maintained file.
- Defaults always include `.env*`, `.envrc`, `.DS_Store`, `.infisical`,
  `.infisical-cache/`, and `.pyenv/`. Python/uv markers or root Python files
  add virtual environments and Python/test/type-checker caches. Package/TypeScript
  manifests or root JS/TS files add Node dependencies, build/test output and local
  package-manager caches. Mixed projects receive both lists.
- `.infisical.json`, `.python-version`, `pyproject.toml`, `uv.lock`, package
  manifests/lockfiles and tool configuration are **not** ignored by default:
  these are normally shared configuration, not secrets. `.pyenv/` covers local
  pyenv installation state rather than the shared runtime-version selection. `.env*` intentionally
  includes example files too; use custom rules to allow a sanitized example.
- Generated files remain **uncommitted** and are **not** included in a push.
  Ignore rules do **not** untrack already-committed files. Review existing history
  for secrets before publishing; this helper does not scan or sanitize history.
- The helper never initializes Git, stages files, creates commits, overwrites
  remotes, or force-pushes. Repository-specific `GIT_DIR`, `GIT_WORK_TREE`,
  `GIT_COMMON_DIR` and `GIT_INDEX_FILE` environment overrides must be unset so
  `git -C` cannot be redirected away from the selected source.
  An explicit source authorizes adding `origin`, provided
  none exists. Other remotes are left untouched. An empty source may be attached
  without pushing, but `--push` requires a commit and an attached branch.
- Push is opt-in even for private repositories. Explicit false always suppresses
  it. Public `--push` is explicit publication authorization and prints a warning.
  Only the current branch and its reachable history are pushed, not all branches
  or uncommitted files. Automatic tag-following and recursive submodule pushes are
  disabled for this operation. Successful pushes set its upstream.
- New `origin` follows `gh config get git_protocol --host github.com`: HTTPS or
  SSH, without introducing another helper-specific setting. This is **github.com**
  only; GitHub Enterprise is outside this interface.
- Ordinary Git URL rewrites are expanded locally before creation (`git ls-remote
  --get-url` does not contact a server). Rewrites between HTTPS and SSH for the
  **same GitHub repository** are accepted. The effective push URL, including
  `pushInsteadOf`, is checked again after adding origin and before any push.
  Redirects to another host/repository are refused; a push-only redirect may
  therefore require recovery after remote creation, but is never pushed to.
- Configure Git authentication yourself (for example `gh auth setup-git` for
  HTTPS or a loaded SSH agent for SSH). Git credential prompts are disabled, and
  SSH pushes put batch mode **before** custom options so a later `BatchMode=no`
  cannot enable prompting. Plain OpenSSH commands with literal arguments (including
  quoted paths containing spaces) are preserved. Shell expressions, `~`/variable
  expansion and custom SSH wrappers require a manual push; use absolute paths for
  automatic pushing. If a key needs unlocking, unlock it yourself and retry the
  reported push command.

The installed `gh repo create --help` (2.102.0) documents `--add-readme` as remote
initialization and `--source`/`--push` as local-history operations. Checking the
[matching CLI source](https://github.com/cli/cli/blob/v2.102.0/pkg/cmd/repo/create/create.go)
shows that `createFromLocal` does **not** pass `AddReadme` into its creation input
(lines 617–628), although the scratch path does. Thus adding `--add-readme` to
`--source . --push` does not provide the requested local README. `ghn` avoids
combining these: it creates an empty remote with `gh repo create OWNER/NAME
--private|--public`, then separately adds `origin` and optionally pushes with Git.
This avoids remote README commits conflicting with local history and makes partial
failure visible. README creation is local even when there is no source.

## Failure and recovery

Authentication is checked before local generation or remote creation. A cancelled
prompt returns nonzero. GitHub permissions, collisions and creation errors return
nonzero with context; generated local files may remain. If a response is lost,
inspect the URL before retrying rather than assuming nothing was created.

After successful creation, a remote-setup or push error explicitly reports
**WAS CREATED**, the URL and recovery instructions. The repository is never
automatically deleted. Do not rerun `ghn` to finish a partial success: inspect
`git remote -v`, fix credentials/configuration, and use the reported Git command.

## Offline verification

```zsh
zsh -n functions/ghn functions/ghnew completions/_ghn completions/_ghnew tests/ghnew.zsh tests/ghnew-completion.zsh
zsh -f tests/ghnew.zsh
zsh -f tests/ghnew-completion.zsh
```

The tests use disposable real Git repositories and a `gh` executable stub; push
and remote-add failure checks stub only those Git boundaries. Test PATH excludes
the installed real GitHub CLI, asserts stub resolution, and uses an invalid test
token as an additional safeguard. These establish local contracts, not GitHub
organization permissions, live API behavior, transport authentication or a real
push. The completion suite exercises real ZLE in a disposable pseudo-terminal,
including a source directory containing spaces, and asserts zero gh/git/ssh calls.
The SSH regression checks effective OpenSSH options with `ssh -G -F /dev/null`
without connecting to a server. Live creation/push requires separate authorization.
