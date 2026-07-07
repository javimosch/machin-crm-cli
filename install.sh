#!/bin/sh
# crm-cli installer — builds the agent-first CRM from source.
# Needs a C compiler (cc). Installs the machin compiler if missing.
set -e
BIN_DIR="${CRM_BIN_DIR:-$HOME/.local/bin}"
SRC_DIR="${CRM_SRC_DIR:-$HOME/.crm-cli-src}"

if ! command -v machin >/dev/null 2>&1; then
  echo "→ installing machin (the language crm-cli is written in)…"
  curl -fsSL https://raw.githubusercontent.com/javimosch/machin/main/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

echo "→ fetching crm-cli…"
if [ -d "$SRC_DIR/.git" ]; then git -C "$SRC_DIR" pull -q --ff-only; else git clone -q https://github.com/javimosch/machin-crm-cli "$SRC_DIR"; fi

echo "→ building…"
( cd "$SRC_DIR" && ./build.sh >/dev/null )

mkdir -p "$BIN_DIR"
ln -sf "$SRC_DIR/crm" "$BIN_DIR/crm"
echo "✓ installed: crm → $BIN_DIR/crm"
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) echo "  add to PATH:  export PATH=\"$BIN_DIR:\$PATH\"";; esac
echo "  next:  crm help"
