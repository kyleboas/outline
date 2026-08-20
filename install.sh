#!/bin/sh
# curl -fsSL https://raw.githubusercontent.com/kyleboas/outline/main/install.sh | sh
#   ... | sh -s -- --shim     also guard `cat`/`sed` so any agent is forced to
#                             outline first, with no harness config
set -e
REPO=https://raw.githubusercontent.com/kyleboas/outline/main
bin=${OUTLINE_PREFIX:-$HOME/.local/bin}
shimdir=$HOME/.local/share/outline/shim
shim=0
[ "${1:-}" = "--shim" ] && shim=1

src=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || src=
[ -f "$src/install.sh" ] || src=   # piped from curl: fetch instead of copying
get() { # get <relpath> <dest>
  if [ -n "$src" ] && [ -f "$src/$1" ]; then cp "$src/$1" "$2"
  else curl -fsSL "$REPO/$1" -o "$2"; fi
  chmod +x "$2"
}

command -v rg >/dev/null || echo "! ripgrep (rg) is required: https://github.com/BurntSushi/ripgrep" >&2

mkdir -p "$bin"
get outline "$bin/outline"
get outline-hook "$bin/outline-hook"
echo "installed outline, outline-hook -> $bin"

paths=$bin
if [ "$shim" = 1 ]; then
  mkdir -p "$shimdir"
  get shim/cat "$shimdir/cat"
  get shim/sed "$shimdir/sed"
  echo "installed cat/sed guards  -> $shimdir"
  paths="$shimdir:$bin"
fi

# add to the shell profile, once
for f in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do [ -f "$f" ] && { rc=$f; break; }; done
rc=${rc:-$HOME/.profile}
line="export PATH=\"$paths:\$PATH\"  # outline"
if grep -qF '# outline' "$rc" 2>/dev/null; then
  echo "already in $rc - leaving it alone"
else
  printf '\n%s\n' "$line" >> "$rc"
  echo "added to $rc"
fi

echo
echo "done. start a new shell, or run:  export PATH=\"$paths:\$PATH\""
[ "$shim" = 1 ] && echo "a bare 'cat file.py' on a long source file is now refused everywhere (OUTLINE_HOOK=0 to bypass)"
exit 0
