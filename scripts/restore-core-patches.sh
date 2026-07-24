#!/bin/bash
# agentmemory 核心 patch 恢复脚本
# 在 `npm update -g @agentmemory/agentmemory` 后执行
set -euo pipefail

DIST_DIR="$HOME/.npm-global/lib/node_modules/@agentmemory/agentmemory/dist"
CACHE_DIR="$HOME/.npm-global/lib/node_modules/@agentmemory/agentmemory/node_modules/@xenova/transformers/.cache/Xenova"
ENV_FILE="$HOME/.agentmemory/.env"
PLIST="$HOME/Library/LaunchAgents/com.agentmemory.plist"

echo "=== agentmemory 核心 patch 恢复 ==="

# 1. 向量模型: multilingual-e5-small
echo "── 1. 向量模型 → Xenova/multilingual-e5-small"
TARGET=$(ls "$DIST_DIR"/src-*.mjs 2>/dev/null | head -1)
if [ -z "$TARGET" ]; then
  echo "   ✗ 找不到 src-*.mjs，请检查版本"
  exit 1
fi

# 替换 embedding 模型
sed -i '' 's|pipeline("feature-extraction", "[^"]*"|pipeline("feature-extraction", "Xenova/multilingual-e5-small"|g' "$TARGET"
# 添加 local_files_only
if ! grep -q 'local_files_only: true' "$TARGET"; then
  sed -i '' 's|pipeline("feature-extraction", "Xenova/multilingual-e5-small")|pipeline("feature-extraction", "Xenova/multilingual-e5-small", { local_files_only: true })|g' "$TARGET"
fi
echo "   ✓ embedding: multilingual-e5-small + local_files_only"

# 2. Reranker: bge-reranker-base
echo "── 2. Reranker → Xenova/bge-reranker-base"
sed -i '' 's|createPipeline("text-classification", "[^"]*"|createPipeline("text-classification", "Xenova/bge-reranker-base"|g' "$TARGET"
if ! grep -q 'quantized: true' "$TARGET"; then
  sed -i '' 's|createPipeline("text-classification", "Xenova/bge-reranker-base")|createPipeline("text-classification", "Xenova/bge-reranker-base", { quantized: true })|g' "$TARGET"
fi
echo "   ✓ reranker: bge-reranker-base + quantized"

# 3. 环境变量
echo "── 3. 环境变量"
touch "$ENV_FILE"
grep -q 'RERANK_ENABLED=true' "$ENV_FILE" 2>/dev/null || echo "RERANK_ENABLED=true" >> "$ENV_FILE"
grep -q 'TRANSFORMERS_REMOTE_HOST=https://hf-mirror.com' "$ENV_FILE" 2>/dev/null || echo "TRANSFORMERS_REMOTE_HOST=https://hf-mirror.com/" >> "$ENV_FILE"
echo "   ✓ .env updated"

# 4. LaunchAgent plist
if [ -f "$PLIST" ] && ! grep -q '<key>RERANK_ENABLED</key>' "$PLIST"; then
  echo "   ⚠ plist 需手动添加 RERANK_ENABLED"
else
  echo "   ✓ plist 已配置"
fi

# 5. 模型缓存检查
echo "── 4. 模型缓存"
MODELS_OK=true
for model in "multilingual-e5-small" "bge-reranker-base"; do
  if [ -d "$CACHE_DIR/$model" ]; then
    echo "   ✓ $model 已缓存"
  else
    echo "   ✗ $model 缺失，正在下载..."
    curl -# -L "https://huggingface.co/Xenova/$model/resolve/main/onnx/model_quantized.onnx" -o "/tmp/${model}_model.onnx" 2>/dev/null || \
    curl -# -L "https://hf-mirror.com/Xenova/$model/resolve/main/onnx/model_quantized.onnx" -o "/tmp/${model}_model.onnx" 2>/dev/null || \
    { echo "   ✗ 下载失败"; MODELS_OK=false; }
    if [ "$MODELS_OK" = true ]; then
      mkdir -p "$CACHE_DIR/$model/onnx"
      mv "/tmp/${model}_model.onnx" "$CACHE_DIR/$model/onnx/model_quantized.onnx"
    fi
  fi
done

echo ""
echo "=== 完成 ==="
echo "请重启 agentmemory: launchctl stop com.agentmemory && launchctl start com.agentmemory"
