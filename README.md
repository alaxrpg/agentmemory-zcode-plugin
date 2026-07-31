# agentmemory ZCode Plugin

ZCode 的 [agentmemory](https://github.com/rohitg00/agentmemory) 持久化记忆插件——自动捕获工具使用、LLM 压缩、跨会话注入上下文。

## 前置要求

- **Node.js** >= 18
- **npm**（`@agentmemory/agentmemory` 全局安装并运行中）
- **ZCode**（macOS）

## 快速安装

```bash
cd ~/项目/agentmemory-zcode-plugin
./install.sh
```

重启 ZCode 即可生效。

## 目录结构

```
agentmemory-zcode-plugin/
├── .zcode-plugin/plugin.json    # ZCode 插件 manifest
├── hooks/hooks.json              # 6 个 hook 事件配置
├── scripts/                      # Hook 执行脚本
│   ├── env-loader.mjs            # 共享 env 加载（无外部依赖）
│   ├── session-start.mjs         # SessionStart (matcher: startup)
│   ├── prompt-submit.mjs         # UserPromptSubmit
│   ├── pre-tool-use.mjs          # PreToolUse (matcher: Edit|Write|Read|Glob|Grep)
│   ├── post-tool-use.mjs         # PostToolUse
│   ├── post-tool-failure.mjs     # PostToolUseFailure ← ZCode 独有
│   └── stop.mjs                  # Stop
├── skills/                       # 8 个可调用技能
│   ├── recall/                   # /recall — 搜索记忆
│   ├── remember/                 # /remember — 保存记忆
│   ├── session-history/          # /session-history — 查看历史
│   ├── forget/                   # /forget — 删除记忆
│   ├── recap/                    # /recap — 摘要回顾
│   ├── handoff/                  # /handoff — 会话交接
│   ├── commit-context/           # /commit-context — 提交上下文
│   └── commit-history/           # /commit-history — 提交历史
├── mcp/.mcp.json                 # MCP 服务器配置
├── .github/workflows/
│   └── auto-update.yml           # GitHub Actions 自动更新
├── install.sh                    # 一键安装脚本
└── .env.example                  # 环境变量模板
```

## 支持的 Hook 事件

| 事件 | Matcher | 说明 |
|------|---------|------|
| SessionStart | startup | 启动新会话时加载记忆上下文（resume 不触发） |
| UserPromptSubmit | — | 用户提交提示词时记录 |
| PreToolUse | Edit\|Write\|Read\|Glob\|Grep | 文件操作前注入关联记忆 |
| PostToolUse | — | 工具调用后捕获操作记录 |
| PostToolUseFailure | — | 工具调用失败时捕获错误信息 |
| Stop | — | 会话结束时触发摘要和清理 |

## MCP 工具

MCP 服务器**由外部 launcher 管理**（如 `~/.agent-config` 的 `agent-sync-mcp-launcher`），插件**不再自动注册** MCP 服务器，避免与 launcher 重复连接产生多个 worker。

手动接入方式（如未使用 launcher）：

```json
{
  "mcpServers": {
    "agentmemory": {
      "command": "npx",
      "args": ["-y", "@agentmemory/mcp"],
      "env": {
        "AGENTMEMORY_URL": "${AGENTMEMORY_URL:-http://localhost:3111}",
        "AGENTMEMORY_SECRET": "${AGENTMEMORY_SECRET:-}",
        "AGENTMEMORY_TOOLS": "${AGENTMEMORY_TOOLS:-all}"
      }
    }
  }
}
```

配置后可得 53 个 MCP 工具，包括：
- `memory_smart_search` — 混合搜索记忆
- `memory_save` — 手动保存记忆
- `memory_sessions` — 查看会话列表
- `memory_recall` — 召回相关记忆
- 等 49 个其他工具...

完整列表见 [agentmemory MCP 文档](https://github.com/rohitg00/agentmemory)。

## 自动更新机制

本仓库配置了 **GitHub Actions** 自动更新工作流：

1. **定时检查**：每天 UTC 08:00 自动运行
2. **版本对比**：从 [npm registry](https://www.npmjs.com/package/@agentmemory/agentmemory) 获取最新版本
3. **自动同步**：如果发现新版本，自动从上游拉取：
   - `scripts/*.mjs` — hook 脚本
   - `skills/*/` — 技能文件
   - `plugin.json` — 更新版本号
4. **提交 & 打 tag**：变更自动 commit 并创建 `vX.Y.Z` tag

### 手动触发

在 GitHub 仓库页面 → **Actions** → **Auto Update from Upstream** → **Run workflow**

## 常见问题

**Q: 安装后插件未生效？**
A: 重启 ZCode。如果仍无效，检查 `~/.zcode/cli/config.json` 是否正确。

**Q: 如何确认 hook 正在工作？**
A: 打开 http://localhost:3113 查看实时观察器，或在 ZCode 中运行 `/recall`。

**Q: 更新后脚本有问题？**
A: 手动触发 GitHub Actions 重新同步，或运行 `./install.sh` 重新安装。

**Q: .env 文件在哪里？**
A: `~/.agentmemory/.env`。首次运行 `install.sh` 会自动创建。

## 许可

Apache-2.0 — 与上游 agentmemory 保持一致。
