---
status: in-progress
project: AI-Gateway
active_backlog_item: 2026-05-03-mvp-litellm-deploy
current_step: M0.5-client-switchover
blocked_at_gate: null
last_commit: pending
last_push: null
retry_count: 0
started: 2026-05-03
updated: 2026-05-03
---

## Context

M0 部署完成 + M0.5b 提前完成（**订阅类聚合从 M2 拉到 M0，详见 [[designs/2026-05-03-pivot-to-subscription-wrappers]]**）。

**双层架构已运行**：
```
[client] → LiteLLM (127.0.0.1:4000) ┬→ Anthropic / OpenAI / DeepSeek (待填 key)
                                     └→ copilot-api (127.0.0.1:4141) → GitHub Copilot Pro (xiaolongde)
```

- LiteLLM PID：见 bash background `b1164l9yw`（litellm 1.83.14）
- copilot-api PID：见 bash background `bo80te665`（监听 :4141, 全网络绑定）
- master key：`.env` 的 `LITELLM_MASTER_KEY`
- 已注册 17 模型：7 直连 API（暂无 key）+ 10 经 Copilot Pro（即用）

**Copilot Pro 即用模型清单**（无需任何 API key，已纳入 $39.9/mo 订阅）：
- copilot/claude-sonnet-4.6 / claude-opus-4.7 / claude-haiku-4.5
- copilot/gpt-5.5 / 5.4 / 5-mini / 4o
- copilot/gemini-2.5-pro / 3.1-pro-preview
- copilot/grok-code-fast-1

端到端验证：`curl http://127.0.0.1:4000/v1/chat/completions -d '{"model":"copilot/claude-sonnet-4.6"...}'` → 返回 "GATEWAY_OK" ✓

## Next action

**用户侧（剩余步骤）**：
1. 切 Claude Code 端点到 `http://127.0.0.1:4000`，API key = `.env` 里 `LITELLM_MASTER_KEY`
2. 切 Cursor 等其他 OpenAI 兼容客户端到 `http://127.0.0.1:4000/v1`
3. （可选）填 `ANTHROPIC_API_KEY` 到 .env，启用直连 Claude API（与 Copilot Pro 通道并存，按需切）
4. 跑 7 天，每天 ≥ 1 次调用；Day 7 写 retro

**长期运行**：当前两个进程都跑在 bash background，会话退出即死。需要装 NSSM 包成 Windows 服务（M1 任务）或开两个常驻 PowerShell 窗口手动 start。

**M0 进度**：
- ✅ M0.1-M0.4 LiteLLM 部署 + commit
- ✅ M0.5b copilot-api 接入（提前从 M2 拉过来）
- ⏳ M0.5 客户端切换（用户）
- ⏳ M0.6-M0.9 7 天观察 + retro
- ⏳ M1.0（新增）start-all.ps1 一键起两服务 + Windows 服务化

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
