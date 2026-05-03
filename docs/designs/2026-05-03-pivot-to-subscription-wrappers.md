---
status: active
project: AI-Gateway
type: design
updated: 2026-05-03
related:
  - "[[2026-05-03-design]]"
---

# ADR: 把订阅类聚合从 M2 拉到 M0/M1

## Status
Active。**修订** [[2026-05-03-design]] 的范围决策，但不 supersede 整体设计（三道前提、Approach B 推荐路径仍然成立）。

## Context

今天上午 office-hours 完成 design APPROVED，明确把"订阅类聚合"defer 到 M2（"撞 Max 限额 ≥ 3 次再做"）。下午 M0 部署 LiteLLM 完成、用户实际看见部署成果后说：

> "我需要的似乎是：把各个 AI 平台的账号订阅服务转化为统一的 API 接口，例如先搞定 GitHub 的 Copilot，我是 39.9 USD/month 会员，但我不希望只在 VSCode 里用 Copilot"

这说明最痛点**不是** API 类聚合（LiteLLM 已经解决），而是**订阅类服务的"客户端解锁"**——把已经付费的 Copilot Pro / Claude Pro 从特定 IDE 里拉出来，用在 Claude Code / Cursor / 自写脚本里。

部署 LiteLLM 后才"看到"真痛点 是有信息价值的——证明用户原本说的"AI token 中转站"的真实驱动是"我付了订阅但被锁在 IDE 里"，office-hours 推回了商业模式但没问到这个具体点。**这是 office-hours 的盲区**，下次设计阶段应该单独问"你已经付费在用的订阅服务有哪些？哪些被锁在了你不想用的客户端里？"

## Decision

**范围变更**（在 [[2026-05-03-design]] Approach A → B → C 路径基础上）：

- **M0.5b 新增**（在 M0.5 客户端切换之前插入）：装 [`ericc-ch/copilot-api`](https://github.com/ericc-ch/copilot-api)，把 GitHub Copilot Pro 暴露成 OpenAI + Anthropic 双兼容端点（默认 4141 端口）
- **M1 修订**（原 Obsidian 仪表盘推到 M1.5）：copilot-api 作为一个 upstream 接入 LiteLLM（Approach B 双层架构落地）
- **M2 保留**：Claude Pro/Max 订阅多账号轮询、ChatGPT Plus / Gemini Advanced 等其他订阅类 wrapper

**M0 deadline 不变**（2026-05-10）。

## Why this pivot is acceptable

1. **不破三道前提**：仍然是自用 / 不造轮子（用 ericc-ch/copilot-api 现成项目）/ 7 天内可用
2. **复用已有工作**：在已部署的 LiteLLM 上加一个 upstream，不推翻 M0
3. **沉没成本可控**：发现真实痛点晚 ~4 小时
4. **价值可立即感知**：用户已付 $39.9/mo Copilot Pro，"解锁到任意客户端"立即兑现这笔已付费用
5. **office-hours 前提 1 没破**：仍然是 v1 仅自用，没动"对外卖"的红线

## Architecture（Approach B 落地图）

```
[Claude Code]  ┐
[Cursor]       ├─→ LiteLLM (127.0.0.1:4000)  ┬→ Anthropic API (直连，需 ANTHROPIC_API_KEY)
[curl/scripts] ┘                              ├→ DeepSeek API (直连)
                                               ├→ OpenAI API (直连)
                                               └→ copilot-api (127.0.0.1:4141) → GitHub Copilot Pro
```

LiteLLM 在 4000，copilot-api 在 4141。客户端**只看见 LiteLLM**。LiteLLM 的 config.yaml 把 copilot-api 当一个 OpenAI-compatible upstream 注册（model_name 例如 `copilot-claude` / `copilot-gpt-5`，litellm_params.model 用 `openai/<model>` + api_base 指向 4141）。

## Risks & Mitigations

| 风险 | 概率 | 缓解 |
|------|-----|------|
| GitHub 检测异常 pattern 封 Copilot 账号 | 中（个人单账号低）| 不滥用并发；不对外分享；调用节奏接近真实 IDE 使用；不极速重试 |
| copilot-api 上游协议被 GitHub 改 | 中 | pin 版本；ericc-ch repo 活跃，通常会快速跟进 |
| 双进程维护负担 | 低 | start.ps1 升级为 start-all.ps1 一键起两服务 |
| OpenAI Schema 行为差异 | 中 | 先小范围测试 chat completion；tool use / stream 单独验证 |
| ToS 风险显性化 | 中 | 项目 CLAUDE.md 已写明绝不对外，单账号自用可接受 |

## Consequences

- 7 天观察期变成"LiteLLM + copilot-api 双层"组合的稳定性观察，retro 问题增加：
  - copilot-api 自己崩过几次？
  - GitHub Copilot 上游有 401 / rate limit 吗？
  - 双层延迟感知如何？
- 加一个进程依赖（copilot-api Node 服务必须和 LiteLLM 一起活）
- 若 copilot-api 停更或被 GitHub 风控破坏，**fallback = 回归 IDE-only 用 Copilot**（用户的订阅价值不丢，只是不解锁）

## Open Questions

- Copilot Pro 实际能调到的模型清单（README 没写全）→ 装完后看 `/v1/models` 返回
- Anthropic-compatible 端点的实测稳定性（Claude Code 可以直接走 4141 不经 LiteLLM？取决于 LiteLLM 是否能干净转发 stream）→ M1 评估
