# AI-Gateway

> BYOA AI 统一网关。聚合自己 + 朋友（受控）的 Claude / OpenAI / DeepSeek / GitHub Copilot Pro 等账号，向下游（Claude Code / Cursor / 自写脚本）暴露统一 OpenAI + Anthropic 双协议端点。**M1.5 起开放给小圈子朋友**（[[designs/2026-05-05-revoke-self-only-premise|2026-05-05 ADR 撤销 v1 仅自用前提]]）。

## 状态
当前阶段：M1.5 准备就绪（2026-05-05）— 等用户装 Docker Desktop + 跑 `docker compose up -d`

## 设计文档
- [[designs/2026-04-24-ideation|2026-04-24 原始构想（Inbox 沉淀）]]
- [[designs/2026-05-03-design|2026-05-03 v1 design（Premise 1 已 partial superseded）]]
- [[designs/2026-05-03-pivot-to-subscription-wrappers|2026-05-03 ADR copilot-api 接入]]
- [[designs/2026-05-05-revoke-self-only-premise|2026-05-05 ADR 撤销"v1 仅自用"]]
- [[designs/2026-05-05-design-v2|2026-05-05 v2 design APPROVED — Friend-Polish + Approach B]]
- [[designs/2026-05-05-vps-deploy-target-impact|2026-05-05 ADR Linux VPS 终态影响 → γ Docker 路径选定]]

## 实现计划
- [[plans/2026-05-03-mvp-litellm-deploy|M0：LiteLLM 部署（已完成）]]
- [[plans/2026-05-05-friend-polish-admin-ui|M1.5：Friend-Polish admin UI（4 卡，进行中）]]

## Docker compose 工作流（M1.5 起的标准启停）

```powershell
# 一次性
cp .env.example .env             # 然后填 POSTGRES_PASSWORD / UI_PASSWORD 等
docker compose build copilot-api
docker compose run --rm copilot-api copilot-api auth   # GitHub device flow

# 日常
docker compose up -d
docker compose logs -f litellm
docker compose down
```

朋友通过 Tailscale 连入：`ANTHROPIC_BASE_URL=http://<tailnet-ip>:4000` + `ANTHROPIC_AUTH_TOKEN=<friend's virtual key>`。

## 给朋友开 key（admin UI 上线后的 5 步）

1. `http://127.0.0.1:4000/ui` 登录（`UI_USERNAME` / `UI_PASSWORD` 见 `.env`）
2. Virtual Keys → Create Key：限 model（白名单选 `claude-*-copilot`）+ 月 budget（保守 $20）+ TPM/RPM 默认
3. Copy 生成的 `sk-...` key 发给朋友
4. 朋友装 Tailscale 加你的 tailnet
5. 朋友改环境变量 + 跑一次任意 model 验证

## 自测

- 入口：`node tests/smoke-test.js`（在 `D:\projects\ai-gateway\` 下跑）
- 前置（裸机模式）：`scripts\start-all.ps1`
- 前置（Docker 模式）：`docker compose up -d`
- 用例清单：[[test-cases]]
- 最近 QA 报告：[[qa-reports/2026-05-05-initial-smoke|2026-05-05 PASS 6/6]]
