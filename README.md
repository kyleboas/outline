# outline

A table of contents for code.

Instead of reading a whole file to find one function, print just the function
names and their line numbers, then read the part you need.

```
$ outline src/fetch.ts
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

Telling an agent in `CLAUDE.md` works most of the time. To enforce it, install
`outline-hook` as a `PreToolUse` hook on `Read`. It blocks whole-file reads of
source files over 200 lines and tells the agent to outline first.

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Read",
        "hooks": [{ "type": "command", "command": "/path/to/outline-hook" }] }
    ]
  }
}
```

It allows the read through when an `offset` or `limit` is given, when the file
is short, and for anything that isn't source code. Set `OUTLINE_HOOK_MAX` to
change the 200-line threshold. Needs `jq`.
