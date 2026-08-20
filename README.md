# outline

A table of contents for code.

Instead of reading a whole file to find one function, print the function names
and their line numbers, then read only the part you need.

```
$ outline src/fetch.ts

src/fetch.ts
6:function ipv4ToInt(address: string): number {
15:function isBlockedIp(address: string): boolean {
41:async function safeUrl(raw: string): Promise<URL> {

$ sed -n '41,60p' src/fetch.ts
```

## Why

This is for coding agents. Most of what an agent spends goes on reading files,
and most of what it reads it doesn't need. Measured across 40 real sessions:
reading files was about 56% of all tokens, and 78% of that came from reading
whole files without limiting the range.

On real source files an outline is ~90% smaller than the file:

```
8 files, full     55,903 tokens
8 files, outline   4,231 tokens
```

The saving comes from throwing away function bodies, not from compressing
anything. Bodies grow as a file grows; names don't. So the bigger the file, the
better this does — and the worse it does on files of many tiny functions.

## Install

```
curl -fsSL https://raw.githubusercontent.com/kyleboas/outline/main/install.sh | sh
```

Needs [ripgrep](https://github.com/BurntSushi/ripgrep). Safe to re-run.

To also install the guards that make agents use it (see below):

```
curl -fsSL https://raw.githubusercontent.com/kyleboas/outline/main/install.sh | sh -s -- --shim
```

## Use

```
outline file.py       one file
outline src/          a folder
outline .             the project
```

Folders skip `node_modules` and `.git` on their own, since ripgrep does.

Whole-project output is often still too big to be useful — outline the folder
you're working in.

## Making an agent use it

Three options, safest first.

### A line in AGENTS.md

```
Before reading a source file over ~200 lines, run `outline <file>` to find the
line number, then read only that range.
```

Most harnesses read `AGENTS.md` or `CLAUDE.md`. No risk, no setup, and agents
follow it most of the time — not always.

### Shell guards (any harness, no config)

Every agent runs shell commands, so guards on `cat` and `sed` catch all of them
with nothing to configure. Install with `--shim` above.

By default they **warn and get out of the way**: `cat file.py` still prints the
file, and one line goes to stderr saying how long it was and what `outline`
would have cost. Nothing can break — scripts, pipelines and cron are unaffected
— and agents see the hint in their tool output.

```
OUTLINE_HOOK=warn    default: hint, then run the command anyway
OUTLINE_HOOK=block   refuse a bare cat/sed -n p of a long source file
OUTLINE_HOOK=off     say nothing
```

Set it per call (`OUTLINE_HOOK=off cat f.py`) or export it. Reach for `block`
only after watching `warn` for a while: blocking can't tell that
`cat f.py | head -5` is already bounded, and refuses it.

### Tool hooks (precise, needs harness config)

`outline-hook` sees the whole command, so it allows what the guards can't —
including `cat f.py | head`. Three calling forms:

```
outline-hook FILE            exit 1 + reason on stderr if FILE is too long
outline-hook --cmd "CMD"     exit 1 + reason if CMD is an unbounded read
outline-hook < hook.json     Claude Code PreToolUse JSON in, deny JSON out
```

Exit 0 allows, exit 1 blocks, reason on stderr. Any harness that runs a command
and reads an exit code can use it; only the JSON form needs `jq`.

Claude Code:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Read|Bash",
        "hooks": [{ "type": "command", "command": "~/.local/bin/outline-hook" }] }
    ]
  }
}
```

`Bash` matters as much as `Read` — `cat file.py` reads just as much as the Read
tool does, and an agent told to prefer shell commands would route around a
`Read`-only matcher entirely.

Anywhere else: call `outline-hook --cmd "$command"` before running a shell
command and refuse it when that exits 1.

### What always gets through

- `Read` given an `offset` or `limit`
- `sed -n` given a line range (`sed -n '41,60p' file.py`)
- with the tool hook: anything piped, redirected, chained, or bounded by
  `head`/`tail`
- short files, and anything that isn't source code

`OUTLINE_HOOK_MAX` changes the 200-line threshold.

## Maintenance

None. It reads your files live, so it can't go stale — nothing is cached or
indexed. Compare ctags, which writes an index that's wrong as soon as you edit.

If you use a language whose definitions don't match the pattern, add a word to
the regex in `outline`. That's the only file.

## Prior art

Editor outline panels, ctags, LSP `documentSymbol`, and aider's repo map all do
this, most of them better. aider additionally ranks functions by how often
they're used, which matters on large projects. This one is two lines.

## Licence

MIT
