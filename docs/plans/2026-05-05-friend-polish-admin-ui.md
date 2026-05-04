---
status: backlog
project: AI-Gateway
type: plan
updated: 2026-05-05
design: "[[2026-05-05-design-v2]]"
estimated_effort_human: "2-3 days"
estimated_effort_cc: "2-3 hours"
---

# M1.5 Plan: Friend-Polish Admin UI（Approach B）

## Goal

落地 [[2026-05-05-design-v2]] 的 Approach B：LiteLLM admin UI + virtual key 隔离 + copilot-api supervisor + Tailscale endpoint + 朋友只读 cost mini-page。

让 Q3 那个具体朋友（persona TODO）今晚就能用 gateway，**不来 ping 用户问 cost**。

## Pre-flight（用户必须先完成）

- [ ] **Persona 卡片**：[[2026-05-05-design-v2]] Target Persona 段的名字 / 角色 / 上次撞坍场景填掉。这是 Assignment 第一条，不补完别走 BACKLOG。
- [ ] 选 DB backend：Postgres 本地服务 vs SQLite（看 LiteLLM 当前版本是否支持 single-instance SQLite for `STORE_MODEL_IN_DB=True`）。决策写到 BACKLOG-1 落地时。
- [ ] 朋友 N 数量明确：当前 Q3 specific 1 人 + 已凑合中其他人 = ?。决定要发几张 virtual key（M1.5 上限 5 张，超过转 M2）。

## BACKLOG（4 卡，sweet spot 边缘）

### BACKLOG-1 · LiteLLM admin UI 激活 + virtual key 工作流

**Scope**：
- 装 Postgres（或确认 SQLite 可用），写 `docker-compose.yml` 或 native install 步骤记到 README
- `.env` 加 `DATABASE_URL` + `STORE_MODEL_IN_DB=True` + `UI_USERNAME=admin` + `UI_PASSWORD=<random 32-byte>`
- `start-all.ps1` 加 Postgres 启动检测 + 等就绪
- `smoke-test.js` 加阶段 4：admin UI `/health` 和 `/ui` 路径返回 200
- 文档化 virtual key 创建步骤（README 加段："给朋友开 key"）

**AC**：
- `:4000/ui` 浏览器能打开 + 用 admin 账号登录
- 通过 `/key/generate` API 能创建带 budget 的 virtual key
- 用新创建的 virtual key 调 `/v1/messages` 通过；超 budget 后调用被拒（HTTP 429 + `BudgetExceededError`）
- smoke-gate `node tests/smoke-test.js` 仍 PASS（含新阶段 4）

**Dependencies**：无

**Effort**：人 4-6h / CC 1h

---

### BACKLOG-2 · copilot-api supervisor

**Scope**：
- 写 `scripts/supervise.ps1`：30-50 行 while-loop，每 30s 检测 `:4141` LISTENING；掉了调 `start-all.ps1` 重起
- 写 `logs/supervisor.log`，每次 detect / restart 加时间戳行
- `start-all.ps1` 加可选 `-Supervise` flag，启动后 fork supervisor

**AC**：
- 手动 `Stop-Process` 杀 copilot-api 后，supervisor 在 ≤ 60s 内恢复 `:4141`
- supervisor.log 记录 detect → restart → resume 完整 cycle

**Dependencies**：BACKLOG-1 不需要（独立组件）

**Effort**：人 2-3h / CC 30 分钟

---

### BACKLOG-3 · Tailscale endpoint 暴露

**Scope**：
- 用户机器装 Tailscale + 加入个人 tailnet
- 朋友各自装 Tailscale 客户端 + 接受用户邀请加入 tailnet
- 朋友配置：`ANTHROPIC_BASE_URL=http://<user-tailnet-ip>:4000`，`ANTHROPIC_AUTH_TOKEN=<friend's virtual key>`
- README 加"朋友 onboarding"段：4 步装 Tailscale + 拿 key + 改 env vars + 验证

**AC**：
- 至少 1 个朋友（Q3 那位）从他自己的机器调 `:4000/v1/messages` 通过 tailnet 成功，返回 200
- 关掉 Tailscale 后调用失败（验证未公网暴露）

**Dependencies**：BACKLOG-1（virtual key 已发）

**Effort**：人 2h（含等朋友配合）/ CC 5 分钟（doc 就行）

---

### BACKLOG-4 · 只读 cost mini-page

**Scope**：
- 写 `web/cost.html`（50 行）：plain HTML + Chart.js（CDN 引）+ 一个 fetch
- 拉 `:4000/spend/logs?api_key=<friend_virtual_key>` 端点（LiteLLM 内置）
- 显示：当月累计 spend、当月 budget、余量、每日 spend 折线图（最近 30 天）
- 鉴权：URL 带 friend's virtual key 作为 query param（朋友自己保密 URL；简单粗暴但够用 for friends-only scope）
- 用 LiteLLM 已有的 static file 能力 mount，或单独跑 `python -m http.server` on `:4002`
- 加 stage 5 到 smoke-test.js：`/cost.html` 返回 200 + 含 "Chart" 字符串

**AC**：
- Q3 那位朋友打开 `http://<tailnet-ip>:4002/cost.html?key=<his-vkey>` 能看到他自己的 spend 卡片
- 看不到其他朋友的 spend（query param 鉴权能 isolate）
- 配额触顶时显示红色 warning bar

**Dependencies**：BACKLOG-1（virtual key + LiteLLM `/spend/logs` 启用）+ BACKLOG-3（Tailscale）

**Effort**：人 3-4h / CC 1h

---

## Test Strategy

- **Smoke**：扩展现有 `tests/smoke-test.js`，加阶段 4（admin UI health）+ 阶段 5（cost.html 可访问）
- **Acceptance per card**：每卡 AC 段。M1.5 完成 = 4 张卡 AC 全过 + smoke gate 全绿
- **End-to-end 验收**：朋友实际从自己机器调 1 次 + 从 cost.html 看到这次调用的 spend

## Success Criteria（complete 完整定义，对齐 design doc）

1. ✅ 至少 1 个朋友（Q3）通过 gateway 实际跑通
2. ✅ 朋友能从一个 URL 看到自己当月消耗 / 配额 / 余量
3. ✅ supervisor 在 2 周内自动恢复 ≥ 1 次 ECONNRESET
4. ✅ 朋友 0 次因 cost 问题 ping 用户

## Risks & Rollback

| 风险 | 缓解 |
|---|---|
| LiteLLM SQLite 不支持 → 必须装 Postgres | BACKLOG-1 先验证；不支持则文档化 Docker Postgres install，5 分钟搞定 |
| Tailscale 朋友 onboarding 摩擦大（朋友懒得装） | 反馈给 retro。如果 ≥ 2 朋友拒绝装，考虑 v1.6 加 Cloudflare Tunnel + Basic Auth fallback |
| LiteLLM `/spend/logs` API 被 master_key 鉴权 | BACKLOG-4 落地时验证；如果 virtual key 看不到自己的 spend，需要写一个反代 endpoint（+1 卡）|
| Postgres 落到本机 → 占内存 + 多一个进程要 supervise | 单实例 Postgres ~50MB，可接受。M2 评估 NSSM + 全量服务化 |

**Abort criteria**（M1.5 完结 4 周后任一发生）：
- 朋友未实际使用 gateway
- 自己回到共享 master_key 的旧路径
- 还在写 web 界面没出货

→ 退到 Approach A 子集（admin UI + virtual key，无 cost mini-page），承认 P2 SLA 在 1-3 年视野下不够 ROI。

## Next steps after this plan APPROVED

1. **现在**：commit 本 plan，BACKLOG.md 补 4 张卡的 wikilink，state.md `active_backlog_item` 切到 `2026-05-05-friend-polish-admin-ui`
2. **执行**：进 `superpowers:subagent-driven-development`，按 BACKLOG-1 → BACKLOG-2 → BACKLOG-3 → BACKLOG-4 顺序跑
3. **每卡完成**：commit + smoke-gate；M1.5 整体完成后跑 `/ship` 出 PR（这个项目无 GitHub remote，本地 commit 即"ship"）
