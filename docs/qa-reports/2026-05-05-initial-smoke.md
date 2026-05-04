---
status: pass
project: AI-Gateway
type: qa
updated: 2026-05-05
---

# smoke-gate 报告 · 初次接入

## 对应 plan
[[plans/2026-05-03-mvp-litellm-deploy]]（M0 部署的伴生套件，从此项目所有改动前后都跑这套）

## 结果
- PASS: **6**
- FAIL: 0
- Exit code: 0

## 用例明细

| # | 用例 | 结果 |
|---|------|------|
| 1.1 | LiteLLM `:4000` LISTENING | PASS |
| 1.2 | copilot-api `:4141` LISTENING | PASS |
| 2 | 无 `x-api-key` → 401/403 | PASS（实得 401） |
| 3.1 | `claude-opus-4-7-copilot` `/v1/messages` 非流式 | PASS |
| 3.2 | `claude-sonnet-4-6-copilot` `/v1/messages` streaming | PASS（6 类 SSE event 齐） |
| 3.3 | `copilot/claude-sonnet-4.6` `/v1/chat/completions`（OpenAI 协议） | PASS |

## 日志

```
=== 阶段 1: 服务健康 ===
  PASS LiteLLM :4000 LISTENING
  PASS copilot-api :4141 LISTENING
=== 阶段 2: 鉴权 ===
  PASS 无 master_key → 401
=== 阶段 3: 核心流量 ===
  PASS claude-opus-4-7-copilot → "OK"
  PASS claude-sonnet-4-6-copilot stream → 6 类 SSE event 齐
  PASS copilot/claude-sonnet-4.6 → "OK"

SMOKE: PASS
```

## 已知不在 smoke 范围（M0 文档化）

- 长 context（>50k tokens）
- 并发请求
- 24h+ 老化 / OAuth token 刷新
- copilot-api ECONNRESET 整进程退出 → BACKLOG M1.5 supervisor
- tool_use / vision / 图片输入
- streaming 非"真流"（first-byte ≈ total，整段缓冲后一次吐）— 协议合规但体感不流式

## 备注

首次为本 Effort 接入 smoke。test-cases.md 与 `tests/smoke-test.js` 同 commit 落地。
