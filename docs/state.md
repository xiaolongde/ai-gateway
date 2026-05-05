---
status: in-progress
project: AI-Gateway
active_backlog_item: 2026-05-05-friend-polish-admin-ui
current_step: M1.5-1-docker-compose-stack
blocked_at_gate: null
last_commit: ce392a9
last_push: null
retry_count: 0
started: 2026-05-03
updated: 2026-05-05
---

## 范围变更（2026-05-05）

立项 v1 "仅自用"前提已被 ADR `b13cb7a` 撤销 → office-hours v2 输出 [[designs/2026-05-05-design-v2]] APPROVED → 拆 plan [[plans/2026-05-05-friend-polish-admin-ui]] 4 卡。M0.6 七天观察期与 M1.5 并行（不冲突，观察数据反而成为新 wedge 的 baseline）。

**G7 cleared 2026-05-05**：persona = 林雅芝（控制工程师），4.25 撞限额（当时在开发）。BACKLOG-1 准备阶段刚开始。

**G1 cleared 2026-05-05**：用户拍板 γ（Docker Desktop 本地 + 同 compose 部 VPS）。本月内迁 VPS。copilot-api 容器化 OK（首次跑要重走 device OAuth）。

**M1.5 重组**：原 BACKLOG-2 (PS supervisor) 删除——Docker `restart: unless-stopped` 取代。新 4 卡：(1) docker-compose stack + admin UI；(2) virtual key 工作流；(3) Tailscale endpoint；(4) cost mini-page。详见更新后的 [[plans/2026-05-05-friend-polish-admin-ui]]。



## Context

M0 部署完成 + M0.5b copilot-api 接入 + **M0.5c Claude Code 反代链路打通** + **M1.0 一键启停脚本**。

**双层架构（含 Anthropic 协议反代）**：
```
[Claude Code]  ───→ ANTHROPIC_BASE_URL=:4000           ┌→ Anthropic / OpenAI / DeepSeek (待填 key)
                                                       │
                    LiteLLM (127.0.0.1:4000)  ─────────┤
                    /v1/messages (Anthropic)           │
                    /v1/chat/completions (OpenAI)      └→ copilot-api (127.0.0.1:4141)
                                                          → GitHub Copilot Pro (xiaolongde)
[Cursor]       ───→ OPENAI_API_BASE=:4000/v1
```

- LiteLLM: 当前 PID 见 `netstat :4000`（用 scripts/start-all.ps1 起）
- copilot-api: 当前 PID 见 `netstat :4141`
- master key: `.env` 的 `LITELLM_MASTER_KEY`
- 已注册 23 模型：7 直连 API + 10 经 Copilot Pro (OpenAI 协议) + **6 经 Copilot Pro (Anthropic 协议，给 Claude Code)**

**Copilot Pro · Anthropic 协议入口**（新增）：
- claude-sonnet-4-copilot / 4-5-copilot / 4-6-copilot
- claude-opus-4-5-copilot / 4-7-copilot
- claude-haiku-4-5-copilot

端到端验证 `curl :4000/v1/messages model=claude-sonnet-4-6-copilot` → 返回标准 Anthropic 响应 ✓
Streaming SSE 完整 (message_start → content_block_delta → message_stop) ✓
`scripts/start-all.ps1` cold-start cycle 验证通过 ✓

## Next action

**用户侧（剩余步骤）**：
1. 配 Claude Code 环境变量，开始日常用：
   ```powershell
   $env:ANTHROPIC_BASE_URL  = "http://127.0.0.1:4000"
   $env:ANTHROPIC_AUTH_TOKEN = "<LITELLM_MASTER_KEY 见 .env>"
   $env:ANTHROPIC_MODEL      = "claude-sonnet-4-6-copilot"
   ```
2. （可选）切 Cursor 等 OpenAI 兼容客户端到 `http://127.0.0.1:4000/v1`
3. （可选）填 `ANTHROPIC_API_KEY` 到 .env，启用 Anthropic 直连通道（与 Copilot Pro 通道并存）
4. 跑 7 天，每天 ≥ 1 次调用；Day 7 写 retro

**长期运行**：当前两个进程都跑在 Start-Process detached，关掉启动它们的 PowerShell 窗口仍能存活，但开机后需手动跑 `scripts/start-all.ps1`。开机自启 / crash 自愈 → M1.5 NSSM。

**M0 进度**：
- ✅ M0.1-M0.4 LiteLLM 部署 + commit
- ✅ M0.5b copilot-api 接入（提前从 M2 拉过来）
- ✅ M0.5c Claude Code 反代 Copilot Pro（Anthropic 协议链路）
- ✅ M1.0 start-all.ps1 / stop-all.ps1（推进到 M1.0 而非原计划 M0.5）
- ⏳ M0.6-M0.9 7 天观察 + retro（等用户日常使用累积数据）
- ⏳ M1.5 NSSM 服务化（已挪到 BACKLOG）

## Log
- 2026-05-03 · bootstrap 完成，junction `D:\projects\ai-gateway\docs`
- 2026-05-03 · office-hours 否决"AI token 中转站业务"，转向 BYOA 自用
- 2026-05-03 · 部署偏离：Docker 缺位 → uv venv
- 2026-05-03 · LiteLLM 1.83.14 启动 OK，注册 7 直连模型
- 2026-05-03 · 编码坑：start.ps1 + config.yaml 改纯 ASCII，.env 加 PYTHONUTF8=1
- 2026-05-03 · 用户回看部署后发现真痛点 = 订阅类聚合，office-hours design 范围变更（ADR `2026-05-03-pivot-to-subscription-wrappers`）
- 2026-05-03 · npm install -g copilot-api 装 ericc-ch/copilot-api
- 2026-05-03 · GitHub OAuth device flow 走通（NODE_USE_ENV_PROXY=1 让 Node fetch 走 Clash 代理 :7897）
- 2026-05-03 · copilot-api 启 :4141，42 个 Copilot 模型可用（xiaolongde 账号）
- 2026-05-03 · LiteLLM config.yaml 加 10 个 `copilot/*` 上游条目，重启
- 2026-05-03 · 端到端测试通过：LiteLLM:4000 → copilot-api:4141 → Claude Sonnet 4.6 返回 "GATEWAY_OK"
- 2026-05-04 · 发现：copilot-api **原生支持 Anthropic `/v1/messages`**（含 streaming SSE），不需要协议转换层
- 2026-05-04 · config.yaml 加 6 个 `claude-*-copilot` (anthropic provider + api_base=:4141)，重启 LiteLLM 验证 `/v1/messages` 链路通
- 2026-05-04 · scripts/start-all.ps1 + stop-all.ps1，PowerShell 坑：`copilot-api.cmd` Start-Process 直调失败 → 用 `powershell.exe -Command` 包装；变量插值 `:$Var` 触发 drive 解析 → `${Var}` 修
- 2026-05-04 · 完整 stop → cold-start cycle 验证通过；e2e check 内嵌脚本（自动 curl `claude-sonnet-4-6-copilot`）
