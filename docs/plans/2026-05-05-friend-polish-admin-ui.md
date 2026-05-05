---
status: in-progress
project: AI-Gateway
type: plan
updated: 2026-05-05
design: "[[2026-05-05-design-v2]]"
related:
  - "[[2026-05-05-vps-deploy-target-impact]]"
estimated_effort_human: "2-3 days"
estimated_effort_cc: "2-3 hours"
---

# M1.5 Plan: Friend-Polish Admin UI（Approach B + Docker stack）

## Goal

落地 [[2026-05-05-design-v2]] 的 Approach B 在 [[2026-05-05-vps-deploy-target-impact]] γ 路径下：用 docker-compose 起 Postgres + LiteLLM + copilot-api 全栈，朋友（林雅芝起手）通过 Tailscale 连本机；本月内迁同一份 compose 到 Linux VPS。

## Pre-flight（用户在 BACKLOG-1 之前必做）

- [ ] **装 Docker Desktop**（用户已 Y）
- [ ] 复制 `.env.example` → `.env`，填：`POSTGRES_PASSWORD` / `UI_PASSWORD`（强随机）；保留已有 `LITELLM_MASTER_KEY` / `LITELLM_SALT_KEY`
- [ ] 决定 N（本月给几张 key）：林雅芝 1 + 已凑合者 = ?，上限 5

## BACKLOG（4 卡，supervisor 卡已删——Docker `restart: unless-stopped` 取代）

### BACKLOG-1 · docker-compose stack 全栈站起

**Scope**：
- 已写：`docker-compose.yml`（Postgres 16-alpine + LiteLLM main-stable + 自建 copilot-api 镜像）+ `docker/copilot-api/Dockerfile`
- 已改：`config.yaml` 加 `general_settings.store_model_in_db: true` + `api_base: os.environ/COPILOT_API_BASE`
- 已改：`.env.example` 加 Postgres / UI / proxy 字段
- **用户操作**：
  1. `docker compose build copilot-api`
  2. `docker compose run --rm copilot-api copilot-api auth`（GitHub device flow，跑一次拿 token，token 落 volume `copilot-data-share`）
  3. `docker compose up -d`
  4. 看 `docker compose logs litellm` 等 `Started server process` + `Application startup complete`
  5. 浏览器 `http://127.0.0.1:4000/ui`，用 `UI_USERNAME` + `UI_PASSWORD` 登录

**AC**：
- `docker compose ps` 三个 container 都 `Up (healthy)`
- `:4000/ui` 能登录看到 admin 面板
- `node tests/smoke-test.js` 6 case 仍 PASS（compose 起来后所有上游路径不变）
- 新增 stage 4（admin UI readiness）PASS

**Dependencies**：Pre-flight 完成

**Effort**：人 1h（含 Docker Desktop install + OAuth）/ CC 0（已写完代码）

---

### BACKLOG-2 · admin UI virtual key 工作流（林雅芝 onboarding）

**Scope**：
- 在 admin UI 创建 1 个 key 给林雅芝：限 `claude-sonnet-4-6-copilot` + `claude-opus-4-7-copilot` 两个 model；月 budget $20（保守）；TPM/RPM 默认
- README 加段："给朋友开 key（5 步）"
- 林雅芝那边：装 Tailscale → 拿 tailnet IP → 改 `ANTHROPIC_BASE_URL=http://<ip>:4000` + `ANTHROPIC_AUTH_TOKEN=<her_vkey>` → 跑一次 CC 验证

**AC**：
- 林雅芝从她机器调 1 次 `claude-opus-4-7-copilot` 返回 200
- admin UI Spend 看板显示她的调用 + 当月累计 cost
- 用她的 key 调 `claude-haiku-4-5-copilot`（不在白名单）→ 401/403

**Dependencies**：BACKLOG-1 + BACKLOG-3 (Tailscale 上)

**Effort**：人 30 分钟（含等林雅芝配合）/ CC 5 分钟（README）

---

### BACKLOG-3 · Tailscale endpoint

**Scope**：
- 用户机器装 Tailscale + 加入个人 tailnet
- 林雅芝装 Tailscale + 接受用户邀请
- 验证朋友机器能 `ping <user-tailnet-ip>` + `curl http://<ip>:4000/health`
- README 加 "Tailscale onboarding（朋友侧 3 步）"

**AC**：
- 林雅芝 Tailscale 状态 connected
- 朋友机器 `curl :4000/health` 返回 200
- 关掉 Tailscale 朋友 curl 失败

**Dependencies**：无（与 BACKLOG-1 并行）

**Effort**：人 30 分钟（朋友配合）/ CC 0

---

### BACKLOG-4 · 只读 cost mini-page

**Scope**：
- 写 `web/cost.html`（50 行）：plain HTML + Chart.js (CDN) + fetch
- 拉 `:4000/spend/logs?api_key=<friend_vkey>` (LiteLLM 内置)
- 显示：当月累计 spend、当月 budget、余量、最近 30 天 spend 折线
- 鉴权：URL `?key=<vkey>` query param（friends-only scope 够用）
- 服务方式：单独跑 `python -m http.server :4002` on host，或挂 LiteLLM 静态目录（看哪个更简）
- smoke stage 5：`/cost.html` 200 + 含 "Chart.js"

**AC**：
- 林雅芝 `http://<tailnet-ip>:4002/cost.html?key=<her-vkey>` 能看到自己的 spend
- 用错 key 看不到（API 返回 empty）
- 配额接近触顶时显示红色 warning

**Dependencies**：BACKLOG-1（virtual key + LiteLLM `/spend/logs` 启用）+ BACKLOG-3（Tailscale）

**Effort**：人 2-3h / CC 1h

---

## VPS Migration（M1.6，本月内）

同一份 `docker-compose.yml`：

1. 买 VPS（Hetzner cax21 €4.5/月 / Vultr / 阿里轻量），ssh 进去
2. `apt install docker.io docker-compose-plugin`
3. `git clone` 项目（或 scp 上传）
4. `.env` 重新填一份（POSTGRES_PASSWORD 等可复用，KEY 重新生成）
5. `docker compose build copilot-api && docker compose run --rm copilot-api copilot-api auth`（VPS 上重走 OAuth）
6. `docker compose up -d`
7. 朋友改 base URL 指 VPS 公网 IP（443 + Caddy/nginx 反代加 TLS，或暂用 IP:4000）
8. tailnet 上的本机 stack 关掉（`docker compose down`）

**未解决** (M1.6 plan 时再答)：
- VPS 走 GitHub Copilot OAuth 是否触发账号异常检测（xiaolongde Copilot Pro 之前只从家庭 IP 调用）
- TLS / domain / 反代选型（Caddy 一行配 TLS 最简）
- 朋友 Tailscale 是否仍要装（VPS 公网 IP + virtual key 限额已是足够防线，可去 Tailscale 简化朋友）

## Test Strategy

- **Smoke**：扩展 `tests/smoke-test.js`：
  - stage 4 (admin UI)：如果 .env 有 DATABASE_URL → 检 `:4000/health/readiness` 200 + `:4000/ui` 200；否则 SKIP
  - stage 5 (cost.html)：如果 `web/cost.html` 存在 → 检 `:4002/cost.html` 200；否则 SKIP
- **每卡 AC**：BACKLOG-N 段
- **End-to-end 验收**：林雅芝实际跑 1 次 + 看到她自己 cost.html

## Success Criteria（M1.5 完成定义，对齐 design doc）

1. ✅ 林雅芝通过 gateway 实际跑通
2. ✅ 林雅芝能从 cost.html 看到当月消耗 / 配额 / 余量
3. ✅ Docker `restart: unless-stopped` 替代 supervisor——容器 crash 自动重起 ≥ 1 次（不需要单独 supervisor 卡）
4. ✅ 林雅芝 0 次因 cost ping 用户

## Risks & Rollback

| 风险 | 缓解 |
|---|---|
| Docker Desktop 装失败 / 占资源太大 | 退回 [[2026-05-05-vps-deploy-target-impact]] α 路径，写 PS install。代价：M1.5 throw-away 1 天 |
| copilot-api OAuth 在 container 重走失败 | container 内 token 路径未必和 npm-on-Windows 一致 → 实测，必要时改 Dockerfile |
| LiteLLM `main-stable` 镜像 prisma migrate 失败 | pin 到 `:v1.83.14-stable` 已验证版本；`docker compose logs litellm` 看 prisma 输出 |
| host Clash :7897 不在 → copilot-api 出不去 | 用户已确认 Clash 常开。失败时 .env 加 COPILOT_HTTP_PROXY 显式指；或 VPS 海外阶段走自然出口 |

**Abort criteria**（M1.5 完结 4 周后任一发生）→ 退到 Approach A 子集。

## Next steps

1. **现在**：commit M1.5-1 准备物（compose / Dockerfile / config 改动 / .env.example / plan + BACKLOG 重组）
2. **用户操作**：装 Docker Desktop → fill .env → `docker compose build` → OAuth → `up -d`
3. **执行**：BACKLOG-1 AC 验完后 → BACKLOG-3 Tailscale → BACKLOG-2 林雅芝 onboard → BACKLOG-4 cost page
4. **本月**：起 M1.6 VPS migration plan
