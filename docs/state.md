---
status: in-progress
project: AI-Gateway
active_backlog_item: 2026-05-03-mvp-litellm-deploy
current_step: M0.5-client-switchover
blocked_at_gate: null
last_commit: 6c7e0f8
last_push: null
retry_count: 0
started: 2026-05-03
updated: 2026-05-03
---

## Context
M0 部署阶段。LiteLLM Proxy 已在本机 127.0.0.1:4000 启动并通过 health/models 验证。**主要部署偏离**：原计划用 Docker，机器上 Docker Desktop 未装 → 改用 uv venv + pip 直接跑（pyproject.toml + start.ps1）。

**deployment fingerprint**：
- 仓库：`D:\projects\ai-gateway`
- venv：`.venv/`（uv sync 创建，litellm 1.83.14）
- 启动：`bash` 里 `cd /d/projects/ai-gateway && set -a && source .env && set +a && .venv/Scripts/litellm.exe --config config.yaml --port 4000 --host 127.0.0.1`（也可用 `start.ps1`）
- 监听：127.0.0.1:4000（仅本机）
- master key：见 `.env` 里 `LITELLM_MASTER_KEY`
- 已注册 7 个模型：claude-sonnet-4-6 / claude-opus-4-7 / claude-haiku-4-5 / gpt-4o / gpt-4o-mini / deepseek-chat / deepseek-reasoner

## Next action

**用户侧（必做才能真用）**：
1. 在 `D:\projects\ai-gateway\.env` 填 `ANTHROPIC_API_KEY=sk-ant-...`（或其他至少一家上游 key）
2. 重启 LiteLLM 让 .env 生效
3. 切 Claude Code / Cursor 的 base URL 到 `http://127.0.0.1:4000`，API key = master key
4. 跑 7 天，每天至少一次调用，积累 cost 数据

**M0 进度**：
- ✅ M0.1 部署形态决策（Docker → uv venv，已记录在 design）
- ✅ M0.2 容器/进程化（start.ps1 + bash launch 两条路径）
- ✅ M0.3 config.yaml 配置 7 个模型
- ✅ M0.4 .gitignore + 首次部署 commit
- ⏳ M0.5 客户端切换（用户操作）
- ⏳ M0.6-M0.9 7 天观察 + retro

## Log
- 2026-05-03 · bootstrap 完成，junction 到 `D:\projects\ai-gateway\docs`
- 2026-05-03 · office-hours 否决"AI token 中转站业务"，转向 BYOA 自用网关
- 2026-05-03 · 部署偏离：Docker 缺位 → uv venv pyproject.toml 路径
- 2026-05-03 · LiteLLM 1.83.14 启动 OK，/health/liveness 200，/v1/models 列出 7 个模型，401 鉴权生效
- 2026-05-03 · 编码坑两个：(1) PowerShell 读 UTF-8 .env 用 GBK 解析 → start.ps1 改纯 ASCII；(2) Python yaml 读 config.yaml 用 GBK → config 改纯 ASCII + 加 PYTHONUTF8=1 双保险
