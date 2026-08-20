# outline

A table of contents for code.

Instead of reading a whole file to find one function, print just the function
names and their line numbers, then read the part you need.

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

On real source files, an outline is 87% smaller than the file:

```
8 files, full     55,903 tokens
8 files, outline   7,442 tokens
```

The saving comes from throwing away function bodies, not from compressing
anything. Bodies grow as a file grows; names don't. So the bigger the file, the
better this does.

## Install

Needs [ripgrep](https://github.com/BurntSushi/ripgrep).

```
curl -o ~/bin/outline https://raw.githubusercontent.com/kyleboas/outline/main/outline
chmod +x ~/bin/outline
```

One file, two lines of shell. Nothing is executed during install and nothing
else on your machine is touched — read it before you run it.

If you also want the guards that make agents use it, there is an `install.sh`
that fetches the extra files and adds a PATH line to your shell profile. It is
short; read it first rather than piping it into a shell.

## Use

```
outline file.py       one file
outline src/          a folder
outline .             the project
```

Folders skip `node_modules` and `.git` on their own, since ripgrep does that.

## Maintenance

None. It reads your files live, so it can't go stale. Nothing is cached or
indexed. Compare ctags, which writes an index that's wrong as soon as you edit.

If you use a language whose definitions don't match the pattern, add a word to
the regex in `outline`. That's the only file.

## Prior art

Editor outline panels, ctags, LSP `documentSymbol`, and aider's repo map all do
this, most of them better. aider additionally ranks functions by how often
they're used, which matters on large projects. This one is two lines.

## Licence

MIT

## Making an agent actually use it

Three ways, from most portable to most precise.

### 1. Shell guards (any harness, no config)

Every agent runs shell commands, so a guard on `cat` and `sed` catches all of
them — Claude Code, pi, Cursor, anything, with nothing to configure.

```
curl -o /tmp/outline-install.sh https://raw.githubusercontent.com/kyleboas/outline/main/install.sh
less /tmp/outline-install.sh          # 40 lines, worth reading
sh /tmp/outline-install.sh --shim
```

It installs the guards and adds a PATH line to your shell profile. Start a new
shell and it is on.

By default it **warns and gets out of the way**. `cat file.py` still prints the
file; a line goes to stderr saying how long it was and what `outline` would have
cost instead. Nothing can break — scripts, pipelines and cron keep working
exactly as before, and agents see the hint in their tool output and adapt.

```
OUTLINE_HOOK=warn    default: print the hint, run the command anyway
OUTLINE_HOOK=block   refuse a bare cat/sed -n p of a long source file
OUTLINE_HOOK=off     say nothing
```

Set it per call (`OUTLINE_HOOK=off cat f.py`) or export it. Only reach for
`block` once you have watched `warn` for a while and know what it catches —
blocking cannot tell that `cat f.py | head -5` is already bounded, and refuses
it. The tool hook below does not have that problem.

### 2. Tool hooks (precise, needs harness config)

`outline-hook` sees the whole command, so it allows what the shim cannot —
including `cat file.py | head`. It takes three calling forms:

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
        "hooks": [{ "type": "command", "command": "/path/to/outline-hook" }] }
    ]
  }
}
```

`Bash` matters as much as `Read` — `cat file.py` reads just as much as the Read
tool does, and agents told to prefer shell commands would otherwise route around
the hook entirely.

Anything else: call `outline-hook --cmd "$command"` before running a shell
command, and refuse it when that exits 1.

### 3. A line in AGENTS.md (portable, not enforced)

```
Before reading a source file over ~200 lines, run `outline <file>` to find the
line number, then read only that range.
```

Most harnesses read `AGENTS.md` or `CLAUDE.md`. Agents follow this most of the
time, not always. Costs nothing, so it is worth having alongside either of the
above.

### What gets through

- `Read` given an `offset` or `limit`
- `sed -n` given a line range (`sed -n '41,60p' file.py`)
- with the hook: anything piped, redirected, chained, or bounded by `head`/`tail`
- short files, and anything that isn't source code

Set `OUTLINE_HOOK_MAX` to change the 200-line threshold.

## Maintenance

None. It reads your files live, so it can't go stale. Nothing is cached or
indexed. Compare ctags, which writes an index that's wrong as soon as you edit.

If you use a language whose definitions don't match the pattern, add a word to
the regex in `outline`. That's the only file.

## Prior art

Editor outline panels, ctags, LSP `documentSymbol`, and aider's repo map all do
this, most of them better. aider additionally ranks functions by how often
they're used, which matters on large projects. This one is two lines.

## Licence

MIT

## Making an agent actually use it

Telling an agent in `CLAUDE.md` / `AGENTS.md` works most of the time. To enforce
it, wire in `outline-hook`. It blocks whole-file reads of source files over 200
lines and tells the agent to outline first.

It takes three calling forms so it fits whatever a harness gives you:

```
outline-hook FILE            exit 1 + reason on stderr if FILE is too long
outline-hook --cmd "CMD"     exit 1 + reason if CMD is an unbounded read
outline-hook < hook.json     Claude Code PreToolUse JSON in, deny JSON out
```

Exit 0 means allow, exit 1 means block, and the reason goes to stderr. Any
harness that can run a command and read an exit code can use it — the first two
forms need nothing but a shell. `jq` is only required for the JSON form.

### Claude Code

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Read|Bash",
        "hooks": [{ "type": "command", "command": "/path/to/outline-hook" }] }
    ]
  }
}
```

`Bash` matters as much as `Read` — `cat file.py` reads just as much as the Read
tool does, and agents told to prefer shell commands would otherwise route around
the hook entirely.

### Anything else

Call `outline-hook --cmd "$command"` before running a shell command, or
`outline-hook "$path"` before reading a file, and refuse the operation when it
exits 1, showing its stderr to the agent.

### What gets through

- `Read` given an `offset` or `limit`
- `sed -n` given a line range (`sed -n '41,60p' file.py`)
- anything piped, redirected, chained, or bounded by `head`/`tail`
- short files, and anything that isn't source code

Only a bare `cat file.py` or `sed -n p file.py` on a long source file is
blocked. Set `OUTLINE_HOOK_MAX` to change the 200-line threshold.
