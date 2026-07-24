#!/bin/bash
# agentmemory 核心 patch 恢复脚本
# 在 `npm update -g @agentmemory/agentmemory` 后执行
set -euo pipefail

DIST_DIR="$HOME/.npm-global/lib/node_modules/@agentmemory/agentmemory/dist"
CACHE_DIR="$HOME/.npm-global/lib/node_modules/@agentmemory/agentmemory/node_modules/@xenova/transformers/.cache/Xenova"
ENV_FILE="$HOME/.agentmemory/.env"
PLIST="$HOME/Library/LaunchAgents/com.agentmemory.plist"
TARGET=$(ls "$DIST_DIR"/src-*.mjs 2>/dev/null | head -1)

echo "=== agentmemory 核心 patch 恢复 ==="

if [ -z "$TARGET" ]; then
  echo "   ✗ 找不到 src-*.mjs，请检查 agentmemory 版本"
  exit 1
fi

# ── 1. 向量模型: multilingual-e5-small ─────────────────────
echo "── 1. 向量模型 → Xenova/multilingual-e5-small (local_files_only)"
sed -i '' 's|pipeline("feature-extraction", "[^"]*"|pipeline("feature-extraction", "Xenova/multilingual-e5-small"|g' "$TARGET"
if ! grep -q 'local_files_only: true' "$TARGET"; then
  sed -i '' 's|pipeline("feature-extraction", "Xenova/multilingual-e5-small")|pipeline("feature-extraction", "Xenova/multilingual-e5-small", { local_files_only: true })|g' "$TARGET"
fi
echo "   ✓ done"

# ── 2. Reranker: bge-reranker-base ────────────────────────
echo "── 2. Reranker → Xenova/bge-reranker-base (quantized)"
sed -i '' 's|createPipeline("text-classification", "[^"]*"|createPipeline("text-classification", "Xenova/bge-reranker-base"|g' "$TARGET"
if ! grep -q 'quantized: true' "$TARGET"; then
  sed -i '' 's|createPipeline("text-classification", "Xenova/bge-reranker-base")|createPipeline("text-classification", "Xenova/bge-reranker-base", { quantized: true })|g' "$TARGET"
fi
echo "   ✓ done"

# ── 3. index.mjs: 清理策略 + 衰减率 ────────────────────────
echo "── 3. index.mjs → 清理策略优化"
INDEX="$DIST_DIR/index.mjs"
if [ -f "$INDEX" ]; then
  # staleSessionDays: 30 → 7
  sed -i '' 's|staleSessionDays: 30,|staleSessionDays: 7,|g' "$INDEX"
  # lowImportanceMaxDays: 90 → 30
  sed -i '' 's|lowImportanceMaxDays: 90,|lowImportanceMaxDays: 30,|g' "$INDEX"
  # decayRate: .05 → 0.5 (可能有多处，只改概念提取那里的)
  sed -i '' 's|decayRate: \.05,|decayRate: 0.5,|g' "$INDEX"
  echo "   ✓ staleSessionDays=7 lowImportanceMaxDays=30 decayRate=0.5"
else
  echo "   ✗ index.mjs not found"
fi

# ── 4. viewer: Token Savings 计算修正 ─────────────────────
echo "── 4. viewer → Token Savings 用活跃会话数计算"
VIEWER="$DIST_DIR/viewer/index.html"
if [ -f "$VIEWER" ]; then
  sed -i '' 's|d\.sessions\.length \* tokenBudget|activeSessions * tokenBudget|g' "$VIEWER"
  echo "   ✓ done"
else
  echo "   ✗ viewer/index.html not found"
fi

# ── 5. 环境变量 ───────────────────────────────────────────
echo "── 5. 环境变量"
touch "$ENV_FILE"
grep -q 'RERANK_ENABLED=true' "$ENV_FILE" 2>/dev/null || echo "RERANK_ENABLED=true" >> "$ENV_FILE"
grep -q 'TRANSFORMERS_REMOTE_HOST=https://hf-mirror.com' "$ENV_FILE" 2>/dev/null || echo "TRANSFORMERS_REMOTE_HOST=https://hf-mirror.com/" >> "$ENV_FILE"
echo "   ✓ .env updated"

# ── 6. LaunchAgent plist ──────────────────────────────────
if [ -f "$PLIST" ]; then
  if ! grep -q '<key>RERANK_ENABLED</key>' "$PLIST"; then
    echo "   ⚠ plist 需手动添加 RERANK_ENABLED=true"
  fi
  if ! grep -q '<key>TRANSFORMERS_REMOTE_HOST</key>' "$PLIST"; then
    echo "   ⚠ plist 需手动添加 TRANSFORMERS_REMOTE_HOST=https://hf-mirror.com/"
  fi
  echo "   ✓ plist 已检查"
fi

# ── 7. 模型缓存检查 ──────────────────────────────────────
echo "── 6. 模型缓存"
for model in "multilingual-e5-small" "bge-reranker-base"; do
  if [ -d "$CACHE_DIR/$model" ]; then
    echo "   ✓ $model 已缓存"
  else
    echo "   ✗ $model 缺失！请手动下载到 $CACHE_DIR/$model/"
  fi
done

# ── 8. 语法校验 ───────────────────────────────────────────
echo "── 7. 语法校验"
if node --check "$INDEX" 2>/dev/null; then
  echo "   ✓ index.mjs syntax OK"
else
  echo "   ✗ index.mjs 语法错误，请检查！"
fi

echo ""
echo "=== 完成，请重启 agentmemory ==="
echo "   launchctl stop com.agentmemory && launchctl start com.agentmemory"
