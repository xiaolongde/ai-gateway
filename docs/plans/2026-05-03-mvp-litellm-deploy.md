---
status: backlog
project: AI-Gateway
type: plan
updated: 2026-05-03
milestone: M0
deadline: 2026-05-10
---

# M0：本周部署 LiteLLM 自用

> 对应 [[../designs/2026-05-03-design|2026-05-03 design]] Approach A 的 Week 1 落地计划。
> **死线**：2026-05-10（7 天）。第 8 天还没自己用上 → abort，回退到 LiteLLM 默认 docker compose 模板，写复盘。

## 前置条件

- [ ] D:\projects\ai-gateway repo 已建（✅ 2026-05-03 完成）
- [ ] 选定部署位置：本机 Docker / 内网小机器 / 公网 VPS（**Day 1 先决定**）
- [ ] 准备好至少 2 家上游 key：Anthropic API + 1 个备选（OpenAI / DeepSeek / Kimi）

## 任务分解

### Day 1-2：基础部署

- [ ] **M0.1** 选择部署形态并落 ADR（Docker 本机 vs VPS）
  - 决策依据：是否有公网访问需求 / 是否多设备共用
  - 写 1 段 ADR 到 `docs/designs/2026-05-03-deploy-target-adr.md`
- [ ] **M0.2** `docker-compose.yml` 拉起 LiteLLM Proxy
  - 镜像：`ghcr.io/berriai/litellm:main-stable`（或最新稳定版）
  - 暴露 4000 端口
  - 持久化：挂载 `./config.yaml` 和 `./db.sqlite`
- [ ] **M0.3** `config.yaml` 配置上游
  - 至少 2 家：`anthropic/*` + 1 个备选
  - 启用 cost tracking（LiteLLM 内置）
  - 主 master key 写入 `.env`（不入 git）
- [ ] **M0.4** `.gitignore` + repo 首次 commit
  - 忽略 `.env` / `*.sqlite` / `*.log`
  - 加 `README.md` 简短部署说明

### Day 3-5：接入下游 + 强制使用

- [ ] **M0.5** Cursor 切到 LiteLLM 端点
  - 改 OpenAI base URL = `http://<gateway>:4000/v1`
  - 改 API key = LiteLLM master key
- [ ] **M0.6** Claude Code 切到 LiteLLM 端点
  - 通过 `ANTHROPIC_BASE_URL` 环境变量
  - 验证 streaming 工作正常
- [ ] **M0.7** **强制自律**：把直连的 API key 临时禁用 / 改名（防止偷偷绕过）
  - 这条是关键，不强制就会回退

### Day 6-7：观察 + retro

- [ ] **M0.8** 每天检查 LiteLLM 的 spend 面板，截图 / 记录每日 token 消耗
- [ ] **M0.9** **Day 7 retro** 写到 `docs/state.md` 的 Log + 单独一份 `docs/qa-reports/2026-05-10-m0-retro.md`，回答：
  1. 真的能自己用吗？还是回退到直连了？为什么？
  2. 哪些痛点 LiteLLM 已经解了？哪些没解？
  3. 现在还想做 Approach C / 订阅类聚合吗？为什么？
  4. 国产 API 的 provider 支持有坑吗？
  5. cost tracking 数据够用吗？是否需要进 D 路径写 PKM 集成？

## 出口标准（M0 完成 = 满足全部 4 条）

1. ✅ LiteLLM Proxy 跑起来 7 天无重启意外死亡
2. ✅ 至少 2 家上游配通，每家至少有一次成功调用
3. ✅ 至少 1 个常用工具（Cursor / Claude Code / 脚本）已切到 LiteLLM 端点
4. ✅ Day 7 retro 已写

## 失败 / abort 规则

满足任意一条 → abort 到 LiteLLM 官方 default config，停止自定义投入，写复盘解释为什么：

- 第 8 天还在调试，没法日常使用
- 发现自己每天偷偷直连
- LiteLLM 本身有 blocker bug 且修复成本 > 1 天
- 撞到上游 API 不兼容（极少见但有可能）

## 不在 M0 范围（明确推迟）

- ❌ 订阅类聚合（Claude Code 订阅 / Copilot 订阅）→ 等 M2 撞墙 ≥ 3 次
- ❌ Web UI 聚合（LibreChat / OpenWebUI）→ 不在 v1 路线
- ❌ Obsidian 集成 / PKM cost 流水（Approach D）→ M1 评估
- ❌ 多账号轮询 → 留给 M2
- ❌ 任何"对外开放"的设想 → v2 之前不评估
