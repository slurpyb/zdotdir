# Agent shell wrapper

Implementation: the autoloaded Zsh function `functions/agent` and its `_agent_*`
helpers. There is no Python or Node launcher. Pi, Rosie, curl and ordinary Unix
file utilities are invoked with argument arrays, not shell-evaluated strings.

## Options

| Option | Effect |
| --- | --- |
| `--add NAME[,NAME]` | Resolve plugin names under `$PLUGINS` (falling back to `$AGENT_PLUGINS_DIR`) and load their Pi package manifests. Explicit extension paths and Pi package sources also work. |
| `-s NAME[,NAME]` | Register local skills with Pi. Immediately after a reference source, select remote skills for that source instead. |
| `-w NAME[,NAME]` | Register local skills without invoking them; never selects remote reference skills. |
| `--with NAME[,NAME]` | Register skills and insert their full instructions at the front of this invocation's prompt. Does not imply print mode. |
| `--ref SOURCE[,SOURCE]` | Delegate to `rosie install ... --ref --agent pi --yes` in the current project. Rosie owns installation, indexing and supported-source restrictions. |
| `--reference SOURCE -l LABEL` | Prepare an invocation-only reference and append a labeled Markdown link to the prompt. Does not index it in the project's instruction files. Repeat for multiple references. |
| `--context FILE [-l LABEL]` | Insert a local text file's contents after the user prompt and before reference links. Supports Markdown, plain text, JSON, CSV, etc.; rejects binary files and URLs. |
| `-l`, `--label` | Reading guidance for the preceding reference or context. Required for `--reference`, optional for `--context`. |
| `--system TEXT_OR_FILE` | Append literal text or a local file's contents to the system prompt. Repeatable; values are joined with newlines. `---system` is also accepted. |
| `--bare` | Disable automatic extension/skill discovery; explicitly requested resources still load. |
| `--sol`, `--luna` | Select the corresponding OpenAI model; otherwise use `openai/gpt-6-astra`. |
| `--low`, `--max` | Set thinking level; otherwise use `medium`. |

Pi's `-t` still means `--tools`. Native Pi options are forwarded. Use `--` to stop
wrapper option parsing. For extension-defined flags, prefer `--flag=value` or
separate the task prompt with `--` to avoid Pi's optional-value ambiguity.

## Skills

Names are found across `$PLUGINS/*/skills/**/SKILL.md`, independent of which
plugins are loaded. Ambiguous names fail rather than silently choosing one; pass
a full skill directory or `SKILL.md` path to disambiguate.

The remote selection `-s` binds to the preceding `--ref` or `--reference` group.
A new resource option begins a new group. Comma-separated `--ref` sources each
receive the selected skill list; Rosie runs once per source/skill pair.

```zsh
agent --add slurpyb -s writing-typescript 'Review this change'
agent --with bun -w bunup -- 'Scaffold a library'
agent --ref github.com/vercel-labs/agent-skills -s react-best-practices
```

These are syntax examples; availability depends on the actual repository and
skill names. Remote installations execute before Pi starts. For direct remote `--ref`
requests, a readable reference and matching Rosie lock entry must exist; an exit
status of zero with no installed reference does not launch Pi.

## Prompt-only references

`--reference` accepts:

- Local files, including PDFs and files outside the project. References are
  copied and linked, not decoded or inlined as context.
- Local skill names or skill directories. Supporting files are copied with the
  skill, not left pointing into a temporary staging directory.
- HTTP(S) document URLs, downloaded with curl (20 MiB maximum; 120-second limit).
- GitHub repository roots (`owner/repo` or a GitHub URL), optionally followed by
  `-s SKILL[,SKILL]`. Rosie prepares remote skills in a disposable project first.
- `npm:PACKAGE`, through Rosie's npm-reference mode, using the current project's
  installed `node_modules` without changing it.

Rosie's reference output is `REFERENCE.md`. For a selected remote skill, the
wrapper instead requests the full skill installation so supporting files survive.
The temporary Rosie's `AGENTS.md`, lockfile and agent symlinks are not copied into
the real project.

Prepared copies live under `.agents/references/agent/ref.XXXXXXXX/`. Unique
subdirectories avoid overwriting existing references. **Ephemeral means the link
belongs only to this invocation**, not that copies are automatically deleted;
they remain available to the session until you remove them.

```zsh
agent --reference ~/notes/design.md -l 'Read when deciding API boundaries' \
      --context ./package.json -l 'Current package configuration' \
      --system 'Keep the change focused' \
      -- 'Implement the requested behavior'
```

Prompt order is: invoked skill bodies, user message(s), context file contents,
then reference links. Skill frontmatter is omitted from invoked bodies. `--with`
does not force `-p`; interactive/print behavior remains Pi's choice unless you
explicitly set it. Native `@file` arguments retain Pi's native attachment behavior,
including images; use `--context` when you need text in the composed position.

## Reload and verify

New shells autoload the current files. To reload an already-open shell:

```zsh
unfunction agent 2>/dev/null
autoload -Uz agent
```

Run the isolated behavior checks:

```zsh
zsh -f ~/.config/zsh/tests/agent.zsh
```

Those checks use real temporary files and a documented Rosie stand-in. They do
not perform network installs or modify any real project's instruction files.
