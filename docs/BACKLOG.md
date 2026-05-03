# AI-Gateway BACKLOG

> 需求池。新增用追加格式：`- [[plans/YYYY-MM-DD-<slug>]]`

## 待开发

- M1.5 NSSM Windows 服务化（开机自启 + crash 自愈 / 后台常驻）
- M1.5 **copilot-api 进程崩溃自愈**：实测 ECONNRESET to api.github.com 时整个进程退出（即使有 NODE_USE_ENV_PROXY=1）。NSSM 的 auto-restart 或 PowerShell while-loop supervisor 二选一
- M2 Claude Code 默认 model 别名映射（如 `claude-sonnet-4-5-20250929` → `claude-sonnet-4-5-copilot`），让 Claude Code 不改 `ANTHROPIC_MODEL` 也能走 Copilot 流量
- M2 评估 Claude Pro/Max 订阅多账号轮询（撞 Copilot Pro 限额 ≥ 3 次再做）
- M2 评估 Obsidian/PKM 集成（每日 cost 流水写回 vault）

## 进行中

- [[plans/2026-05-03-mvp-litellm-deploy]] · M0 部署 LiteLLM 自用（M0.1-M0.5c 完成；剩 M0.6-M0.9 七天观察 + retro，等用户日常使用累积数据）

## 已完成

- 2026-05-04 · [[plans/2026-05-04-anthropic-via-copilot-and-startall]] · M0.5c (Claude Code 反代 Copilot Pro) + M1.0 (一键启停脚本)
