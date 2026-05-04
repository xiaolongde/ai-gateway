# AI-Gateway

> 个人的 BYOA（Bring-Your-Own-Account）AI 统一网关——聚合自己的 Claude（订阅 + API key）/ OpenAI / DeepSeek / Kimi / 通义 等账号，向下游（Cursor / Cline / 自写脚本）暴露一个 OpenAI-compatible 端点。**v1 仅自用，不对外提供服务**。

## 状态
当前阶段：立项（2026-05-03）— 待 M0 部署 LiteLLM 自用

## 设计文档
- [[designs/2026-04-24-ideation|2026-04-24 原始构想（Inbox 沉淀）]]
- [[designs/2026-05-03-design|2026-05-03 Office Hours 综合设计（推荐 LiteLLM 自部署起步）]]

## 实现计划
- [[plans/2026-05-03-mvp-litellm-deploy|M0：本周部署 LiteLLM 自用]]

## 自测
- 入口：`node tests/smoke-test.js`（在 `D:\projects\ai-gateway\` 下跑，前置 `scripts\start-all.ps1`）
- 用例清单：[[test-cases]]
- 最近 QA 报告：[[qa-reports/2026-05-05-initial-smoke|2026-05-05 PASS 6/6]]
