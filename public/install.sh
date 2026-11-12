#!/bin/sh
# NuclearLang installer for Linux and macOS:
#
#   curl -fsSL https://nuclearlang.github.io/install.sh | sh
#   curl -fsSL https://nuclearlang.github.io/install.sh | sh -s -- --version 0.2.0
#   curl -fsSL https://nuclearlang.github.io/install.sh | sh -s -- --uninstall
#
# It downloads the release of this system and architecture (Linux x86_64/aarch64, any distribution: the binaries are
# static; macOS Intel/Apple silicon) from GitHub, checks its SHA-256, installs it in ~/.local/share/nuclearlang with
# `nuclear`, `dragonfly` and `nuclear-lsp` linked in ~/.local/bin, puts that folder in the PATH of your shells, gives
# the AI agents the `nuclear` skill and, when VS Code is there, installs its extension. No sudo.
#
# Options (or environment): --version <v> (NUCLEAR_VERSION, default: the latest), --no-modify-path
# (NUCLEAR_NO_MODIFY_PATH=1), --no-vscode, --no-agent, --uninstall. NUCLEAR_INSTALL and NUCLEAR_BIN change the folders;
# NUCLEAR_REPO the repository (owner/name) and NUCLEAR_DOWNLOAD the base url of the files (a mirror).
set -eu

REPO=${NUCLEAR_REPO:-nuclearlang/nuclear}
VERSION=${NUCLEAR_VERSION:-latest}
INSTALL=${NUCLEAR_INSTALL:-$HOME/.local/share/nuclearlang}
BIN=${NUCLEAR_BIN:-$HOME/.local/bin}
MODIFY_PATH=${NUCLEAR_NO_MODIFY_PATH:+0}
MODIFY_PATH=${MODIFY_PATH:-1}
VSCODE=1
AGENT=1
SKILL_DIRS="$HOME/.claude/skills $HOME/.agents/skills $HOME/.codex/skills"
MARK="# added by the NuclearLang installer"

say() { printf '%s\n' "$*" >&2; }
fail() { say "error: $*"; exit 1; }

while [ $# -gt 0 ]; do
  case $1 in
    --version) VERSION=${2:?--version needs a value}; shift ;;
    --no-modify-path) MODIFY_PATH=0 ;;
    --no-vscode) VSCODE=0 ;;
    --no-agent) AGENT=0 ;;
    --uninstall)
      rm -f "$BIN/nuclear" "$BIN/dragonfly" "$BIN/nuclear-lsp" "$BIN/nuclear-loop"
      rm -rf "$INSTALL"
      for d in $SKILL_DIRS; do rm -rf "$d/nuclear"; done
      for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.config/fish/conf.d/nuclearlang.fish"; do
        [ -f "$rc" ] && grep -q "$MARK" "$rc" && { grep -v "$MARK" "$rc" > "$rc.nuclear" && mv "$rc.nuclear" "$rc"; }
      done
      command -v code >/dev/null 2>&1 && code --uninstall-extension nuclearlang.nuclearlang >/dev/null 2>&1 || true
      say "NuclearLang uninstalled."
      exit 0 ;;
    -h|--help) sed -n '2,17p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
  shift
done

# --- this system ---
case "$(uname -s)" in
  Linux) os=linux ;;
  Darwin) os=macos ;;
  MINGW*|MSYS*|CYGWIN*) fail "on Windows run in PowerShell: irm https://nuclearlang.github.io/install.ps1 | iex" ;;
  *) fail "unsupported system: $(uname -s) (Linux, macOS and Windows are)" ;;
esac
case "$(uname -m)" in
  x86_64|amd64) arch=x86_64 ;;
  aarch64|arm64) arch=aarch64 ;;
  *) fail "unsupported architecture: $(uname -m) (x86_64 and aarch64 are)" ;;
esac
# a Mac with Apple silicon running this shell under Rosetta still gets the native build
if [ "$os" = macos ] && [ "$arch" = x86_64 ] && [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" = 1 ]; then
  arch=aarch64
fi

if command -v curl >/dev/null 2>&1; then
  get() { curl -fsSL --retry 3 "$1" -o "$2"; }
  read_url() { curl -fsSL --retry 3 "$1"; }
elif command -v wget >/dev/null 2>&1; then
  get() { wget -q "$1" -O "$2"; }
  read_url() { wget -qO- "$1"; }
else
  fail "curl or wget is needed"
fi
command -v tar >/dev/null 2>&1 || fail "tar is needed"

# --- which release ---
if [ "$VERSION" = latest ]; then
  if [ -n "${NUCLEAR_DOWNLOAD:-}" ]; then
    VERSION=$(read_url "$NUCLEAR_DOWNLOAD/latest" | tr -d '[:space:]')
  else
    # the latest release's tag: from the redirect of /releases/latest (no API limit), else from the API
    tag=""
    if command -v curl >/dev/null 2>&1; then
      tag=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest" 2>/dev/null || true)
      tag=${tag##*/}
    fi
    [ -n "$tag" ] && [ "$tag" != latest ] || tag=$(read_url "https://api.github.com/repos/$REPO/releases/latest" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)
    VERSION=$tag
  fi
  VERSION=${VERSION#v}
  [ -n "$VERSION" ] && [ "$VERSION" != latest ] || fail "could not find the latest release of $REPO"
fi
name="nuclearlang-$VERSION-$os-$arch.tar.gz"
base=${NUCLEAR_DOWNLOAD:-https://github.com/$REPO/releases/download/v$VERSION}

# --- download and check ---
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM
say "Downloading NuclearLang $VERSION for $os $arch..."
get "$base/$name" "$tmp/$name" || fail "could not download $base/$name"
get "$base/$name.sha256" "$tmp/$name.sha256" || fail "could not download the checksum of $name"
want=$(cut -d ' ' -f 1 < "$tmp/$name.sha256")
if command -v sha256sum >/dev/null 2>&1; then got=$(sha256sum "$tmp/$name" | cut -d ' ' -f 1)
else got=$(shasum -a 256 "$tmp/$name" | cut -d ' ' -f 1); fi
[ "$want" = "$got" ] || fail "the download is damaged (SHA-256 does not match); try again"

# --- install ---
tar -xzf "$tmp/$name" -C "$tmp"
rm -rf "$INSTALL"
mkdir -p "$(dirname "$INSTALL")" "$BIN"
mv "$tmp/nuclearlang" "$INSTALL"
for b in nuclear dragonfly nuclear-lsp; do ln -sf "$INSTALL/bin/$b" "$BIN/$b"; done
# nuclear-loop needs node (the Loop without an editor, ADR-0102)
if [ -f "$INSTALL/bin/nuclear-loop" ]; then ln -sf "$INSTALL/bin/nuclear-loop" "$BIN/nuclear-loop"; fi
"$BIN/nuclear" dialect list >/dev/null || fail "the installed nuclear does not run on this system"

if [ "$AGENT" = 1 ]; then
  for d in $SKILL_DIRS; do
    mkdir -p "$d" && rm -rf "$d/nuclear" && cp -R "$INSTALL/agents/skills/nuclear" "$d/"
  done
fi

if [ "$VSCODE" = 1 ] && command -v code >/dev/null 2>&1; then
  vsix="nuclearlang-$VERSION.vsix"
  if get "$base/$vsix" "$tmp/$vsix" 2>/dev/null; then
    code --install-extension "$tmp/$vsix" --force >/dev/null 2>&1 && say "VS Code extension installed."
  fi
fi

# --- the PATH ---
case ":$PATH:" in
  *":$BIN:"*) on_path=1 ;;
  *) on_path=0 ;;
esac
if [ "$on_path" = 0 ] && [ "$MODIFY_PATH" = 1 ]; then
  line="export PATH=\"$BIN:\$PATH\" $MARK"
  for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    if [ -f "$rc" ] || [ "$rc" = "$HOME/.profile" ]; then
      grep -q "$MARK" "$rc" 2>/dev/null || printf '\n%s\n' "$line" >> "$rc"
    fi
  done
  if command -v fish >/dev/null 2>&1; then
    mkdir -p "$HOME/.config/fish/conf.d"
    echo "fish_add_path $BIN $MARK" > "$HOME/.config/fish/conf.d/nuclearlang.fish"
  fi
fi

say ""
say "NuclearLang $VERSION is installed: nuclear and dragonfly in $BIN."
if [ "$on_path" = 0 ]; then
  if [ "$MODIFY_PATH" = 1 ]; then say "Open a new terminal (or run: export PATH=\"$BIN:\$PATH\")."
  else say "Add $BIN to your PATH: export PATH=\"$BIN:\$PATH\""; fi
fi
say "Start with: nuclear help   ·   dragonfly new my_app   ·   dragonfly doctor"
