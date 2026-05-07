---
status: backlog
project: AI-Gateway
type: plan
updated: 2026-05-07
design: "[[2026-05-05-vps-deploy-target-impact]]"
related:
  - "[[2026-05-05-friend-polish-admin-ui]]"
  - "[[2026-05-05-design-v2]]"
estimated_effort_human: "1-2 days (含 OAuth canary + DNS + Caddy)"
estimated_effort_cc: "1-2 hours"
---

# M1.6 Plan: Linux VPS Migration（β path）

## Goal

把 M1.5 已验过的 docker-compose stack 整套搬到 Linux VPS，朋友（林雅芝起手）从公网 HTTPS 接入；本地家用 stack 保留 1 周观察期后再下线。承接 [[2026-05-05-vps-deploy-target-impact]] β 路径，design v2 5 Premises 不变。

## 触发条件 / Pre-flight（按顺序，前一个完成才到下一个）

- [ ] **M1.5 BACKLOG-3 Tailscale 通**：朋友能从她机器走 tailnet 调本地 stack ≥ 1 次
- [ ] **本地 stack 跑 1 周**：从 2026-05-06 起算，至 2026-05-13 不重启自愈，朋友实际产生 ≥ 5 次调用 + 看过自己的 cost.html
- [ ] **用户决定 VPS provider**（默认推荐：阿里轻量香港 ¥24/月）
- [ ] **域名**：用户名下有域名可指 VPS（A record），或买一个（cn 后缀 ≈ ¥30/年，com 后缀 ≈ ¥60/年）
- [ ] **OAuth canary 决策**：是否先用 burner GitHub 账号在 VPS 上 OAuth 一次，验证不触发 xiaolongde 主账号风控

## BACKLOG（5 卡）

### BACKLOG-1 · OAuth canary（账号风险熔断）

**Scope**：用一个 burner GitHub 账号（不是 xiaolongde），订阅 Copilot Pro 1 个月（$10），在 VPS 上跑完整 OAuth device flow + 调 1 次 chat completion。**目的不是真用 burner，是探"Copilot Pro 能否从 VPS IP 调用"**。

**两种结果**：
- ✅ Burner 没被风控 → xiaolongde 主账号上 VPS 风险中等可控，进 BACKLOG-2
- ❌ Burner 被 flag / 限速 / 锁号 → **abort β path**，回到 α（保持本地，朋友走 Tailscale）

**AC**：
- Burner 账号 OAuth device flow 在 VPS 上跑通
- 连续调用 7 天 ≥ 50 次 chat completion 无 401 / 异常
- xiaolongde 主账号期间无任何风控通知

**Dependencies**：Pre-flight 全部完成

**Effort**：人 30 分钟（注册 + 订阅 + OAuth）+ 7 天等待 / CC 0；¥70 burner 订阅成本（不可回收）

**Rollback**：Burner 出问题不影响主账号；最多损失 $10

---

### BACKLOG-2 · VPS provisioning + Docker 安装

**Scope**：
- 注册 VPS（推阿里轻量香港 24元/月 ¥24，2C2G 60G SSD 30M 带宽）
- 域名 A record 指 VPS IP，等 DNS 生效（10 分钟到 24 小时）
- ssh 进 VPS：
  ```bash
  apt update && apt install -y docker.io docker-compose-plugin git ufw
  systemctl enable --now docker
  usermod -aG docker $USER  # 重 ssh 生效
  ```
- ufw 防火墙：开 22/80/443，**关掉 4000/4141/4002/5432/7897 全部**
- `git clone <repo>` 到 `/opt/ai-gateway`

**AC**：
- `docker version` server 端通
- `ufw status` 显示只 22/80/443 ALLOW
- 仓库代码在 VPS 上能 build copilot-api image

**Dependencies**：BACKLOG-1 PASS

**Effort**：人 1h / CC 0

---

### BACKLOG-3 · `.env` 重新生成 + compose 改造

**Scope**：

VPS 上**全新** `.env`，**4 个 secret 全部重生成**（不复用本地）：

```bash
LITELLM_MASTER_KEY=sk-litellm-$(openssl rand -hex 16)
LITELLM_SALT_KEY=$(openssl rand -hex 16)
POSTGRES_PASSWORD=$(openssl rand -hex 16)
UI_PASSWORD=$(openssl rand -hex 12)
```

`COPILOT_HTTP_PROXY` / `COPILOT_HTTPS_PROXY` **留空**（VPS 海外不需要 Clash）。

**`docker-compose.yml` 改造**（与本地版差异）：

| 字段 | 本地 | VPS |
|------|------|-----|
| `postgres.ports` | `0.0.0.0:5432:5432` | **删** ports 字段（compose 网络内部访问足够，不暴露公网） |
| `litellm.ports` | `0.0.0.0:4000:4000` | `127.0.0.1:4000:4000`（只让 Caddy 反代访问） |
| `copilot-api.ports` | `0.0.0.0:4141:4141` | **删** ports（仅内网访问） |
| `costpage.ports` | `0.0.0.0:4002:80` | `127.0.0.1:4002:80`（让 Caddy 反代） |
| `copilot-api.volumes` token | `~/.local/share/copilot-api:...` | **删 bind mount**，改用 docker volume `copilot-data:/root/.local/share/copilot-api` |

**OAuth 重走**（独立步骤）：
```bash
docker compose run --rm copilot-api copilot-api auth
```
浏览器开 device URL，登 burner 账号（BACKLOG-1 验过）→ token 写入 docker volume，下次 up 自动用。

**AC**：
- VPS 上 `docker compose up -d` 4 容器全 Healthy
- 公网扫端口（用 https://www.yougetsignal.com/tools/open-ports/）只看到 80/443，4000/4141/4002/5432 全 closed
- VPS 内 `curl http://127.0.0.1:4000/health/readiness` → 200
- 公网 `curl http://VPS_IP:4000/...` → connection refused（已通过 ufw 屏蔽）

**Dependencies**：BACKLOG-2

**Effort**：人 30 分钟 / CC 0

---

### BACKLOG-4 · Caddy + TLS（公网入口）

**Scope**：

`/opt/ai-gateway/Caddyfile`：
```caddy
gateway.<your-domain>.com {
    # LiteLLM 主入口（Anthropic + OpenAI 协议都走这里）
    reverse_proxy 127.0.0.1:4000
}

cost.<your-domain>.com {
    # 朋友 cost mini-page
    reverse_proxy 127.0.0.1:4002
}
```

加 `caddy` service 到 docker-compose（或单独装 system caddy）：

```yaml
caddy:
  image: caddy:2-alpine
  restart: unless-stopped
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - ./Caddyfile:/etc/caddy/Caddyfile:ro
    - caddy-data:/data
    - caddy-config:/config
  network_mode: host  # or bridge with explicit upstream IPs
```

Caddy 自动 ACME letsencrypt 拉证书。

**AC**：
- `curl https://gateway.<domain>/health/readiness` 200（含合法 TLS 证书）
- `curl http://gateway.<domain>/...` → 308 redirect to https
- `curl https://cost.<domain>/cost.html?key=<vkey>` 200

**Dependencies**：BACKLOG-3 + 域名 DNS 已生效

**Effort**：人 30 分钟 / CC 30 分钟（写 Caddyfile）

---

### BACKLOG-5 · 朋友 base URL 切换 + 本地 stack 退役

**Scope**：

林雅芝侧 env 改：

```powershell
$env:ANTHROPIC_BASE_URL  = "https://gateway.<domain>"
$env:ANTHROPIC_AUTH_TOKEN = "sk-..."  # VPS 上重新发的 vkey（不复用本地的）
$env:ANTHROPIC_MODEL      = "claude-sonnet-4-6-copilot"
```

VPS admin UI 给她重新发 vkey（同 M1.5-2 流程，月 $20，sonnet-4-6/opus-4-7 白名单）。

**Tailscale 退役**（可选）：朋友若同意，可卸 Tailscale；公网 IP + virtual key 限额已是足够防线。

**本地 stack 观察期**（推荐保留 1 周作为 fallback）：
- VPS 切流量后本地 stack 不动，仅 `docker compose stop`
- 1 周后没人喊 issue 才 `docker compose down -v`

**AC**：
- 林雅芝从她机器（**关掉 Tailscale**）调 1 次 → 200
- VPS admin UI Spend 看板显示她的调用
- VPS cost.html `https://cost.<domain>/cost.html?key=<her-vkey>` 显示她的 spend
- 7 天观察期内 VPS stack `docker compose ps` 始终 4/4 Healthy
- 7 天后本地 stack 安全 `down -v`

**Dependencies**：BACKLOG-4 + 林雅芝配合

**Effort**：人 30 分钟（朋友配合）+ 7 天观察 / CC 5 分钟

---

## Test Strategy

- **smoke**：复用 `tests/smoke-test.js`，env 变量 `LITELLM_BASE_URL=https://gateway.<domain>` 跑全套 9 stage。新增 stage 6（TLS 证书有效性）。
- **每卡 AC** 见上
- **End-to-end**：林雅芝完整跑 1 次（关 Tailscale）+ 看到自己 cost 页 + 1 周内 ≥ 10 次自然调用无 issue
- **公网安全**：`nmap -p 1-65535 VPS_IP` 只看到 22/80/443 三个端口

## Risks & Rollback

| 风险 | 概率 | 缓解 |
|------|-----|------|
| **xiaolongde Copilot 账号被风控** | 🔴 中-高 | BACKLOG-1 burner canary 先验；如发生 → abort + 退回本地 stack |
| Postgres 公网暴露被扫 | 🔴 高（如忘改 ports） | BACKLOG-3 删 postgres ports；ufw 兜底；扫端口验证 |
| Caddy ACME 证书拉失败 | 🟡 中 | DNS 必须先生效；80 端口必须开（ACME http-01 challenge） |
| 国内访问海外 VPS 慢 | 🟡 中 | 选香港/日本 VPS；M2 加 CDN（Cloudflare 前置）|
| LiteLLM 镜像 prisma 在 VPS 失败 | 🟢 低 | 本地已验过；VPS 用同 image + PG 16 一致 |
| 朋友 `https://gateway.<domain>` 被 GFW 反向干扰 | 🟢 低 | 朋友在国内访问海外 VPS 是正常出墙路径，不会被针对 |

**Rollback procedure**：
1. VPS：`docker compose down -v`，DNS A record 切回 `127.0.0.1` 或删，林雅芝改回 Tailscale + 本地 base URL
2. 本地 stack 仍在（观察期未下线）→ 立即接手
3. 时间窗：≤ 30 分钟

## Success Criteria（M1.6 完成定义）

1. ✅ 林雅芝从公网 https 通过 LiteLLM 调用 Claude/Copilot Pro 模型成功
2. ✅ xiaolongde Copilot 主账号无风控通知（7 天后判）
3. ✅ VPS stack `restart: unless-stopped` 自愈 ≥ 1 次（人为 `docker kill` 验）
4. ✅ Caddy TLS A+ 评级（ssllabs.com 测）
5. ✅ 公网扫描只暴露 22/80/443
6. ✅ 月成本 ≤ ¥30（VPS ¥24 + 域名摊 ¥3-5）

## Abort Criteria

任一发生立即停 VPS 路径，回退到本地 + Tailscale：
- BACKLOG-1 canary burner 账号 7 天内被 flag
- xiaolongde 主账号收到任何 GitHub 风控通知
- VPS 月成本超 ¥100（性能/带宽撞墙必须升级）
- 朋友实际使用 < 月 5 次（投资回报负，VPS 不值得）

## Next steps

1. **现在**（CC 自动）：写本 plan + 改本地 compose 把 postgres 端口收紧（VPS-ready 预加固，本地仍能用）+ 更新 BACKLOG / state
2. **本周**（人 + 朋友）：跑 BACKLOG-3 Tailscale + 林雅芝实测 1 次（M1.5 收尾）
3. **本月内**（人）：M1.5 观察 1 周后开 BACKLOG-1 OAuth canary（决策点）
4. **canary PASS 后**（人 + CC）：BACKLOG-2/3/4/5 顺序推进，预计 2-3 天完成迁移
