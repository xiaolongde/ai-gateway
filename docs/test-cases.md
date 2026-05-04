---
type: test-cases
project: AI-Gateway
updated: 2026-05-05
---

# AI-Gateway 自测用例

入口：`node tests/smoke-test.js`（在 `D:\projects\ai-gateway\` 下跑）。
前置：`scripts\start-all.ps1` 已起好两个进程，`.env` 里有 `LITELLM_MASTER_KEY`。

| # | 用例 | 期望 | 覆盖 smoke-test.js 函数 |
|---|------|------|-----------------------|
| 1.1 | LiteLLM `:4000` 端口监听 | `netstat` 含 `:4000 ... LISTENING` | `checkPortListening` |
| 1.2 | copilot-api `:4141` 端口监听 | `netstat` 含 `:4141 ... LISTENING` | `checkPortListening` |
| 2 | 不带 `x-api-key` 调 `/v1/messages` | HTTP 401 或 403 | `checkAuthRejection` |
| 3.1 | `claude-opus-4-7-copilot` `/v1/messages` 非流式 | HTTP 200 + `content[0].text` 非空 + `model` 字段回显 | `checkAnthropicNonStream` |
| 3.2 | `claude-sonnet-4-6-copilot` `/v1/messages` `stream=true` | SSE 含 6 类 event：`message_start` / `content_block_start` / `content_block_delta` / `content_block_stop` / `message_delta` / `message_stop` | `checkAnthropicStreaming` |
| 3.3 | `copilot/claude-sonnet-4.6` `/v1/chat/completions` (OpenAI 协议) | HTTP 200 + `choices[0].message.content` 非空 | `checkOpenAICompletions` |

## 不在 smoke 范围（已知缺口）

下列项可能在长期日用中暴露问题，但不挂 smoke gate（成本/收益比不合算）：

- 长 context（>50k tokens 输入）
- 并发请求（多 CC session 同时打）
- 24h+ 老化（OAuth token 刷新 / Copilot Pro 限额触发）
- copilot-api 进程在 `ECONNRESET to api.github.com` 时整进程退出（已知，BACKLOG M1.5 待补 supervisor）
- tool_use / vision / 图片输入

## 退出码约定

- `0` = 全部 PASS
- `1` = 任意 case FAIL

供 `smoke-gate` skill 解析。
