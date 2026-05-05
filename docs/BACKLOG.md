# AI-Gateway BACKLOG

> 需求池。新增用追加格式：`- [[plans/YYYY-MM-DD-<slug>]]`

## 待开发

### M1.5 · Friend-Polish（4 卡，[[plans/2026-05-05-friend-polish-admin-ui]] / Docker-stack 路径）

- [[plans/2026-05-05-friend-polish-admin-ui]] · M1.5 主 plan
- M1.5-1 docker-compose stack 全栈站起（Postgres + LiteLLM + copilot-api + admin UI）
- M1.5-2 admin UI virtual key 工作流（林雅芝 onboarding，README 文档化）
- M1.5-3 Tailscale endpoint 暴露（朋友通过 tailnet 接入；本月内迁 VPS 后可去）
- M1.5-4 朋友只读 cost mini-page（HTML + Chart.js + LiteLLM `/spend/logs`）

> ~~M1.5 copilot-api supervisor (PS while-loop)~~ — **删**。Docker `restart: unless-stopped` 替代。

### M1.6 · VPS migration（本月内）

- M1.6-1 买 VPS（Hetzner / Vultr / 阿里轻量）
- M1.6-2 同 `docker-compose.yml` 部到 VPS
- M1.6-3 VPS 上 GitHub Copilot OAuth 重走（监 xiaolongde 账号是否触发异常检测）
- M1.6-4 TLS / 反代 (Caddy) + 朋友 base URL 切换到公网

### M2 · Future（撞墙再做）

- M2 NSSM Windows 服务化（已不需要——γ 路径放弃 Windows native 部署）
- M2 Claude Code 默认 model 别名映射（如 `claude-sonnet-4-5-20250929` → `claude-sonnet-4-5-copilot`）
- M2 多 Copilot 账号轮询（撞 Copilot Pro 限额 ≥ 3 次再做；当前 P3=3b 单账号共享）
- M2 实时计费 dashboard（M1.5 用 LiteLLM 自带日聚合即可）
- M2 上游凭据 web 热加载（当前 `.env` + 重启在 < 13 模型规模下不痛）
- M2 Obsidian/PKM 集成（每日 cost 流水写回 vault；M1.5 admin UI 是数据源）

## 进行中

- [[plans/2026-05-03-mvp-litellm-deploy]] · M0 部署 LiteLLM 自用（M0.1-M0.5c 完成；剩 M0.6-M0.9 七天观察 + retro，等用户日常使用累积数据）

## 已完成

- 2026-05-04 · [[plans/2026-05-04-anthropic-via-copilot-and-startall]] · M0.5c (Claude Code 反代 Copilot Pro) + M1.0 (一键启停脚本)
