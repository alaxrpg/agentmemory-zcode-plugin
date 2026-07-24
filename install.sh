#!/bin/bash
# agentmemory ZCode Plugin — One-Click Installer
# Usage: ./install.sh
set -euo pipefail

PLUGIN_NAME="agentmemory"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZCODE_PLUGIN_DIR="$HOME/.zcode/cli/plugins/cache"
VERSION=$(node -p "require('$PROJECT_DIR/.zcode-plugin/plugin.json').version" 2>/dev/null || echo "0.9.28")
TARGET_DIR="$ZCODE_PLUGIN_DIR/$PLUGIN_NAME/$VERSION"
CONFIG="$HOME/.zcode/cli/config.json"
ENV_FILE="$HOME/.agentmemory/.env"

echo "╔══════════════════════════════════════════╗"
echo "║  agentmemory ZCode Plugin Installer     ║"
echo "║  Version: $VERSION"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── 1. Symlink plugin into ZCode cache ──────────────────────
echo "── 1. Plugin symlink"
mkdir -p "$(dirname "$TARGET_DIR")"
if [ -L "$TARGET_DIR" ] || [ -d "$TARGET_DIR" ]; then
  rm -rf "$TARGET_DIR"
fi
ln -sf "$PROJECT_DIR" "$TARGET_DIR"
echo "   ✓ $TARGET_DIR -> $PROJECT_DIR"

# ── 2. Clean stale config entries ───────────────────────────
echo "── 2. Config cleanup"
if [ -f "$CONFIG" ]; then
  # Remove old hooks section pointing to Codex paths
  if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
with open('$CONFIG') as f:
    cfg = json.load(f)

removed_hooks = False
if 'hooks' in cfg:
    del cfg['hooks']
    removed_hooks = True

removed_mcp = False
if 'mcp' in cfg and 'servers' in cfg['mcp']:
    if 'agentmemory' in cfg['mcp']['servers']:
        del cfg['mcp']['servers']['agentmemory']
        removed_mcp = True

with open('$CONFIG', 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')

if removed_hooks: print('   ✓ Removed old hooks section')
if removed_mcp: print('   ✓ Removed duplicate MCP server entry')
if not removed_hooks and not removed_mcp: print('   ✓ Already clean')
" 2>/dev/null || echo "   ⚠ python3 not available, skipped config cleanup"
  else
    echo "   ⚠ config.json not found, skipping"
  fi
else
  echo "   ⚠ config.json not found, skipping"
fi

# ── 3. Seed .env if missing ─────────────────────────────────
echo "── 3. Environment file"
if [ ! -f "$ENV_FILE" ]; then
  mkdir -p "$(dirname "$ENV_FILE")"
  cp "$PROJECT_DIR/.env.example" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "   ✓ Created $ENV_FILE"
else
  echo "   ✓ $ENV_FILE already exists"
fi

# ── Done ─────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  Installation complete!                 ║"
echo "╠══════════════════════════════════════════╣"
echo "║  Restart ZCode for changes to apply.    ║"
echo "║  Plugin directory: $TARGET_DIR"
echo "║  Viewer: http://localhost:3113          ║"
echo "╚══════════════════════════════════════════╝"
