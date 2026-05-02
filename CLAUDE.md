# AI-Gateway — Claude Code 项目说明

## 项目性质
个人 AI 服务统一网关。聚合自己的 Claude（订阅 + API key）/ OpenAI / DeepSeek / Kimi / 通义 等账号，对下游（Cursor / Cline / 自写脚本）暴露统一的 OpenAI-compatible 端点。**v1 仅自用，不对外提供服务**。

## 技术栈
- LiteLLM Proxy（Python）+ Docker Compose 部署
- 配置：`config.yaml`（key / 路由 / cost tracking）
- 可能加薄壳：Obsidian/PKM 集成（每日 cost 流水写回 vault）

## 本项目特殊约定
- 方法论默认跟随全局 `~/.claude/CLAUDE.md`，本文件只放覆盖项
- **绝不**把这个工具变成对外服务（即使朋友想付钱也拒绝）。原因见 `docs/designs/2026-05-03-design.md` Phase 3 前提 1。如果想破例必须先重读那份 design 的"商业模式承重墙"章节
- **绝不**从零造轮子。必须基于 LiteLLM / NewAPI / One-API 之一改。如果碰到无法绕过的硬伤要切方向，先在 `docs/designs/` 加一份 ADR 论证

## smoke 测试
`node tests/smoke-test.js`（未建，待 M0 完成补）；覆盖见 `docs/test-cases.md`
