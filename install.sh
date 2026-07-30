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

# ── 2. Merge agentmemory hooks into ZCode config ────────────
echo "── 2. Register hooks"
if [ -f "$CONFIG" ]; then
  if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys, os

with open('$CONFIG') as f:
    cfg = json.load(f)

# Initialize hooks section
if 'hooks' not in cfg:
    cfg['hooks'] = {'enabled': True, 'events': {}}
cfg['hooks']['enabled'] = True
events = cfg['hooks'].setdefault('events', {})

# Scripts directory (resolved at install time)
scripts_dir = os.path.join('$TARGET_DIR', 'scripts')

# ============ agentmemory hook definitions ============
# Use absolute paths so hooks survive plugin updates
am_hooks = {
    'SessionStart': [{
        'matcher': 'startup',
        'hooks': [{
            'type': 'command',
            'command': f'node \"{scripts_dir}/session-start.mjs\"',
            'statusMessage': 'agentmemory: loading session context'
        }]
    }],
    'UserPromptSubmit': [{
        'hooks': [{
            'type': 'command',
            'command': f'node \"{scripts_dir}/prompt-submit.mjs\"',
            'statusMessage': 'agentmemory: recalling relevant memories'
        }]
    }],
    'PreToolUse': [{
        'matcher': 'Edit|Write|Read|Glob|Grep',
        'hooks': [{
            'type': 'command',
            'command': f'node \"{scripts_dir}/pre-tool-use.mjs\"'
        }]
    }],
    'PostToolUse': [{
        'hooks': [{
            'type': 'command',
            'command': f'node \"{scripts_dir}/post-tool-use.mjs\"'
        }]
    }],
    'PostToolUseFailure': [{
        'hooks': [{
            'type': 'command',
            'command': f'node \"{scripts_dir}/post-tool-failure.mjs\"'
        }]
    }],
    'Stop': [{
        'hooks': [{
            'type': 'command',
            'command': f'node \"{scripts_dir}/stop.mjs\"'
        }]
    }]
}

# ============ Merge: remove old agentmemory entries, add current ============
added = 0
for event, entries in am_hooks.items():
    # Remove old agentmemory entries from this event
    if event in events:
        old_count = len(events[event])
        events[event] = [e for e in events[event]
                         if not any('agentmemory' in h.get('command', '') or 'agentmemory-zcode-plugin' in h.get('command', '')
                                    for h in e.get('hooks', []))]
        if len(events[event]) < old_count:
            print(f'   ✓ Cleaned {old_count - len(events[event])} stale {event} entries')
    # Add current agentmemory entries
    if event not in events:
        events[event] = []
    events[event].extend(entries)
    added += 1
    print(f'   ✓ {event} ({len(entries)} hook(s))')

with open('$CONFIG', 'w') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write('\n')

print(f'   ✓ Registered {added}/6 hook events')
" 2>/dev/null || echo "   ⚠ python3 not available, skipped hook registration"
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
