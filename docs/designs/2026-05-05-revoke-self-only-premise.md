---
status: active
project: AI-Gateway
type: design
updated: 2026-05-05
revokes_premises_in: "[[2026-05-03-design]]"
related:
  - "[[2026-05-03-design]]"
  - "[[2026-05-03-pivot-to-subscription-wrappers]]"
---

# ADR: 撤销"v1 仅自用"前提

## Status
Active。**部分 supersedes** [[2026-05-03-design]] 的 Premise 1 + Constraints 中"绝不对外"项；保留三道前提中的 Premise 2（不造轮子）和 Premise 3（MVP 本周可用，已达成）。

## Context

立项后 2 天日用过程中，用户主动提出"我希望有一个 web 端的管理工具，可以用来配置账号"。澄清需求边界时，5 个关键问题的答案：

| 问题 | 答案 |
|---|---|
| 上游账号会上几个？ | **10+** |
| 写入是手动 `.env` 还是 web 热加载？ | **web 热加载** |
| 用户：单人 vs 给朋友也开 key？ | **给朋友开几个 key** |
| 上游 key 固定还是常换？ | **常换** |
| 消耗看板：日粒度 vs 实时？ | **实时** |

这套答案在结构上**就是** [[2026-05-03-design]] 的 Approach B（NewAPI 风格中转站）+ 当时被否决的"AI token 中转站"商业路径——只是不直接收钱。具体对应：

| 原 design 否决的 | 新答案 |
|---|---|
| "未来对外卖" | 给朋友开几个 key（缩水版多用户） |
| 多账号池化（M2 撞墙再做） | 10+ 上游（即刻做） |
| Cost tracking PostgreSQL（M0 不展开） | 实时计费 dashboard |
| 手动改 config.yaml | web 热加载 |

## Decision

**撤销以下条款：**

1. [[2026-05-03-design]] **Premise 1**："v1 不考虑对外、v2 之前不重新评估"
2. [[2026-05-03-design]] **Constraints 第 3 项**："绝不对外：即使朋友想付费也拒绝"
3. [[2026-05-03-design]] **Approach B 的 ❌ 项**："架构偏中转站，自用偏重"——现在中转站架构变成正向选择

**保留以下条款：**

1. **Premise 2**：不从零造轮子。新 design 仍优先评估 NewAPI / One-API / LiteLLM-with-DB 等现成方案。
2. **Premise 3**：MVP 已在 2026-05-04 达成（M0 部署 + Claude Code 反代 + smoke 6/6 PASS），这一前提**不动**。
3. **[[2026-05-03-pivot-to-subscription-wrappers]]** 的 M0.5b 决策（copilot-api 接入 LiteLLM）继续生效——它是新方向的基础设施。

**冻结以下项直至新 design APPROVED：**

- BACKLOG 上 M1.5 / M2 全部条目（admin UI / NSSM / 多账号轮询 / PKM 集成）的具体形态待定
- 当前 [[plans/2026-05-03-mvp-litellm-deploy]] M0.6-M0.9 七天观察期**继续跑**（不会浪费——是新 design 的 baseline 数据）

## Why this revocation is acceptable

1. **诚实优于一致性**：用户两天前 office-hours 否决方向，两天后日用反馈把它推回来。如果默默扩 scope、不撤销 ADR，相当于在自己骗自己的工作流（CLAUDE.md 项目原文："默默遵从会丢失两个信号"）。明文撤销是诚实记账。
2. **沉没成本可控**：M0 已落地的 LiteLLM + copilot-api 双层架构在新方向下仍然是核心 upstream，不浪费。
3. **风险显性化**："对外即使是朋友"会激活 GitHub Copilot ToS 风险（原 ADR pivot 第 5 行明示"绝不对外"是规避手段）—— 新 design 必须正面处理 ToS / GitHub 检测风险。

## Risks（新方向引入）

| 风险 | 概率 | 严重性 |
|---|---|---|
| GitHub 检测 Copilot 多账号 → 封号 | 中-高 | 高（损失订阅 + 朋友联坐）|
| ToS 显性违反（账号共享 ≈ 转售） | 高 | 中-高（个人账号但被注销）|
| Multi-tenant 鉴权写错 → 朋友看到彼此 spend | 中 | 高（信任损失）|
| 实时计费需要 stream 计算 → 工程量爆炸 | 中 | 中 |
| 给朋友支持的隐性时间成本 | 高 | 中（蚕食工作时间）|

## What's next

1. **本 ADR commit 后**：调用 `/office-hours`（Builder mode 或 Startup mode 视用户判断）重新做范围设计
2. **新 design 输出**：`designs/2026-05-05-design-v2.md`，frontmatter 标 `supersedes: [[2026-05-03-design]]`
3. **新 design APPROVED 后**：写 `plans/2026-05-05-<slug>.md`，BACKLOG 重排

## What I learned about workflow

- **省略 office-hours 的代价是 ADR**：用户日用 2 天后冒出 5 个改方向的需求，本来如果立刻"行行行那就做"，3 周后会发现项目变成了 ToS 灰区中转站而没人记得是怎么变过去的。flag + 多选题这个动作把"漂移"变成"决策"。
- **范围扩张 vs 决策修订**：原以为 D 是 scope 扩张（量上加），实际是 premise 变化（质上换）。下次出现"用户答案集与立项 ADR 矛盾"时，第一反应应该是检查 premise 是否被破，而不是估工程量。
