#!/bin/sh
# crm-cli installer.
#   curl -fsSL https://raw.githubusercontent.com/javimosch/machin-crm-cli/master/install.sh | sh
#
# Prefers a prebuilt release binary (no compiler, no git). If none matches this OS/arch,
# or the downloaded binary can't run here (older glibc / musl / missing libssl3), it falls
# back to build-from-source (needs machin + a C compiler + git). Honors CRM_BIN_DIR.
set -e
REPO="javimosch/machin-crm-cli"
BIN_DIR="${CRM_BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$BIN_DIR"

os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
case "$arch" in x86_64|amd64) arch=x64 ;; aarch64|arm64) arch=arm64 ;; esac
asset="crm-${os}-${arch}"

try_prebuilt() {
  url=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
        | grep -oE "https://[^\"]*/${asset}([\"]|$)" | tr -d '"' | head -1)
  [ -n "$url" ] || { echo "  no prebuilt for ${os}/${arch} — building from source."; return 1; }
  echo "→ downloading prebuilt ${asset} …"
  tmp=$(mktemp)
  curl -fSL --progress-bar "$url" -o "$tmp" || { rm -f "$tmp"; return 1; }
  chmod +x "$tmp"
  # Verify it actually runs on THIS system before trusting it (libc/openssl/musl skew).
  if "$tmp" version >/dev/null 2>&1; then
    mv "$tmp" "$BIN_DIR/crm"
    echo "✓ installed prebuilt: crm → $BIN_DIR/crm"
    return 0
  fi
  echo "  prebuilt didn't run here (libc/openssl mismatch) — building from source instead."
  rm -f "$tmp"; return 1
}

build_from_source() {
  command -v git >/dev/null 2>&1 || { echo "crm-cli: need git (or a matching prebuilt) to install" >&2; exit 1; }
  if ! command -v machin >/dev/null 2>&1; then
    echo "→ installing machin (the language crm-cli is written in) …"
    curl -fsSL https://raw.githubusercontent.com/javimosch/machin/main/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
  if ! command -v cc >/dev/null 2>&1 && ! command -v gcc >/dev/null 2>&1 && ! command -v clang >/dev/null 2>&1; then
    echo "crm-cli: need a C compiler (cc/gcc/clang) to build from source" >&2; exit 1
  fi
  SRC_DIR="${CRM_SRC_DIR:-$HOME/.crm-cli-src}"
  echo "→ fetching source …"
  if [ -d "$SRC_DIR/.git" ]; then
    git -C "$SRC_DIR" fetch -q origin && git -C "$SRC_DIR" reset -q --hard origin/master
  else
    git clone -q "https://github.com/$REPO" "$SRC_DIR"
  fi
  echo "→ building …"
  ( cd "$SRC_DIR" && ./build.sh >/dev/null )
  cp "$SRC_DIR/crm" "$BIN_DIR/crm"   # copy, not symlink — survives removal of the source dir
  echo "✓ built + installed: crm → $BIN_DIR/crm"
}

try_prebuilt || build_from_source

if "$BIN_DIR/crm" version >/dev/null 2>&1; then
  case ":$PATH:" in *":$BIN_DIR:"*) echo "  next: crm help" ;; *) echo "  add to PATH:  export PATH=\"$BIN_DIR:\$PATH\"   then: crm help" ;; esac
else
  echo "crm-cli: installed to $BIN_DIR/crm but it won't run — missing runtime libs? (needs libssl3 + libsqlite3)" >&2
  exit 1
fi
