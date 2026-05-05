---
status: active
project: AI-Gateway
type: design
updated: 2026-05-05
related:
  - "[[2026-05-05-design-v2]]"
  - "[[plans/2026-05-05-friend-polish-admin-ui]]"
---

# ADR: Linux VPS 终态对 M1.5 architecture 的影响

## Status
Active。**追加约束**到 [[2026-05-05-design-v2]]——不撤销决策，但补上 Q4/Constraints 阶段漏问的部署目标维度。

## Context

2026-05-05 office-hours v2 完成 design APPROVED 后、BACKLOG-1 implementation 半途，用户补充：

> "最终会部署到 Linux 的 VPS 上"

这是 office-hours 没问到、design v2 没记的 constraint。Q4 narrowest wedge 隐式假设了 "Windows 本机部署 + Tailscale 暴露给朋友"——朋友连用户家电脑。

VPS 终态意味着：
- 朋友连**公网 IP**（不再 Tailscale；或 VPS 也加入 tailnet）
- Postgres / LiteLLM / copilot-api 全部要在 Linux 跑
- PowerShell 脚本（start-all / stop-all / 待写的 supervise / install-postgres）**全部是 throw-away**
- Docker compose 是统一双端的最自然抽象

## Why this surfaced late

- Office-hours Q1-Q5 都聚焦 demand / status quo / wedge / observation——无一问 deployment target
- Q6 future-fit 问"3 年后产品价值"但没问"3 年内 infra 怎么演化"
- Constraints 段我推断的"v1 仅自用 → 单机 Windows" 是从原 design Premise 延续，没在 v2 重新质询
- 用户也没主动提，可能潜意识里"先在本机跑通"

**Lesson for next office-hours**：Phase 1 contextual gathering 应该加一题"目标部署形态"（laptop / NAS / VPS / cloud / edge），它影响整个 architecture 选型

## Decision

**M1.5 暂停在 BACKLOG-1 工程开始之前**。等用户从以下 3 选项明确 deployment 路径：

### α. Local-Windows 先跑，Linux migration 留 M2（"throw-away accept"）
- M1.5 完整在 Windows 落地，林雅芝走 Tailscale 接入用户家电脑
- 写 `scripts/install-postgres.ps1`（admin script）+ PS supervisor
- VPS 阶段当 M2 单独 plan，配套 `docker-compose.yml` + bash supervisor + Linux install doc 重新做一遍
- **代价**：M1.5 写的所有 PS 脚本都是 throw-away（≈ 2-3 天人时）；好处是林雅芝最快 unblock
- **timeline 到林雅芝能用**：1-2 天

### β. VPS-first（"直接到位"）
- 用户先去买 VPS（Hetzner cax11 / Vultr / 阿里轻量应用服务器，¥40-80/月）
- 写 `docker-compose.yml`：Postgres + LiteLLM + copilot-api（如果 copilot-api 在 VPS 跑要解决 GitHub OAuth 重新走流程）
- 朋友直接连 VPS 公网 IP，按 LiteLLM master/virtual key 鉴权（不依赖 Tailscale）
- supervisor 转 Docker `restart: unless-stopped` 或 systemd
- **代价**：等 VPS 注册 + DNS + domain 配置，≥ 3-5 天到林雅芝能用；额外月成本
- **好处**：0 throw-away；架构干净
- **风险**：copilot-api 在 VPS 上 OAuth 体验未验证，xiaolongde Copilot 账号从 VPS IP 调用可能触发 GitHub 异常检测（**比家庭 IP 风险高一档**）

### γ. Docker-Desktop 中间路径
- 用户在本机装 Docker Desktop（之前主动避开过，原因是不想增加运行时依赖）
- 写 `docker-compose.yml`，本地用 Docker 跑 Postgres + LiteLLM + copilot-api
- 朋友走 Tailscale 接入用户家电脑（同 α）
- VPS 阶段直接 `docker-compose up -d` 复用同一份 compose
- **代价**：用户必须接受 Docker Desktop（~2GB 安装 + 后台资源占用）
- **好处**：0 throw-away；统一双端
- **风险**：用户之前避 Docker 的理由如果仍成立（比如机器性能 / 不喜欢运行时），γ 不可选

## What's halted in M1.5 right now

- ⏸ BACKLOG-1（admin UI + virtual key）：等 deployment 选项决策
- ⏸ BACKLOG-2（supervisor）：实现技术依赖 α/β/γ（PS / systemd / Docker restart）
- ⏸ BACKLOG-3（朋友接入）：依赖 endpoint 在哪
- ⏸ BACKLOG-4（cost mini-page）：HTML 跨平台无差，可后做

## Already locked-in 不变的部分

- design v2 的 5 Premises（P1-P5）都不受 deployment 选项影响
- BACKLOG 4 卡的拆法和 Acceptance Criteria 不变（只是实现技术随平台换）
- Q3 林雅芝 persona 不变（她不在乎在哪台机器跑，只在乎能用 + 自助查 cost）

## Risks if we keep going on Windows-only without flag

- 我会在隔夜写 ~2 天人时的 PowerShell 脚本 + Windows-only Postgres install + 待 VPS 时全部丢弃
- 用户明早醒来发现工程做了一半但前提刚被推翻
- "继续推进"的 user delegate 边界被滥用

→ 因此选**停**，给用户明早决策权。

## Open Questions to user

1. **VPS 时间表**：M1.5 deadline 内（4 周）能买 VPS 吗？还是更晚？
2. **Docker 接受度**：本机装 Docker Desktop 是否 OK（vs 之前避开的理由是否还成立）？
3. **VPS-from-China 网络**：你需要从中国到 GitHub Copilot 上游的延迟稳定吗？海外 VPS 的 GitHub 反向代理没问题，但国内 VPS 调 api.github.com 需要 Clash / 代理转出
4. **公网暴露 vs Tailscale-on-VPS**：朋友是否愿意装 Tailscale；vs 你愿意把 LiteLLM master_key 放公网（virtual key 限额作为唯一防线）

## Recommended

凭信息有限，**γ (Docker-Desktop 中间路径)** 是技术上最优——0 throw-away、双端统一、`docker-compose.yml` 是 lingua franca。但前提是用户能接受 Docker Desktop 本地装。

如果 γ 被否（用户的 Docker 避开理由仍成立），**α** 是 M1.5 应急选择，VPS 用 M2 重做时承接 lessons。

**β 不推荐**先做：VPS 注册 + 域名 + 在 VPS 上 Copilot OAuth 风险 = 3 天延期；林雅芝当前在等。

## Next Step

明早用户在以上 α / β / γ 拍板。我看到选择后：
- α → 写 PS install + supervisor，1-2 天 ship
- β → 帮用户挑 VPS provider，写 docker-compose.yml，3-5 天 ship
- γ → 写 docker-compose.yml + 文档化 Docker Desktop install，1-2 天 ship
