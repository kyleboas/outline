#!/bin/sh
# install.sh [--shim] [--prefix DIR]
#   installs `outline` and `outline-hook` to DIR (default ~/.local/bin)
#   --shim also installs the cat/sed guards and prints the PATH line for them
set -e
prefix=$HOME/.local/bin; shim=0
while [ $# -gt 0 ]; do
  case $1 in
    --shim)   shim=1 ;;
    --prefix) prefix=$2; shift ;;
    *) echo "usage: install.sh [--shim] [--prefix DIR]" >&2; exit 1 ;;
  esac
  shift
done
src=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

command -v rg >/dev/null || echo "warning: ripgrep (rg) not found - outline needs it" >&2

mkdir -p "$prefix"
cp "$src/outline" "$src/outline-hook" "$prefix/"
chmod +x "$prefix/outline" "$prefix/outline-hook"
echo "installed outline, outline-hook -> $prefix"
case ":$PATH:" in *":$prefix:"*) ;; *) echo "  add to your shell profile:  export PATH=\"$prefix:\$PATH\"" ;; esac

[ "$shim" = 1 ] || exit 0
d=$HOME/.local/share/outline/shim
mkdir -p "$d"
cp "$src/shim/cat" "$src/shim/sed" "$d/"
chmod +x "$d/cat" "$d/sed"
cat <<EOF

installed cat/sed guards -> $d
  add to your shell profile, BEFORE anything else touches PATH:

    export PATH="$d:\$PATH"

  then a bare \`cat file.py\` on a long source file is refused everywhere -
  every agent, every harness, no config. Escape with OUTLINE_HOOK=0.
EOF
