# AI-Gateway CHANGELOG

## [Unreleased]

- 2026-05-03 · **M0.5b 完成**：copilot-api 接入 LiteLLM 双层架构（订阅类聚合从原计划 M2 提前到 M0）。`ericc-ch/copilot-api` npm 装在 `:4141`，OAuth device flow 走通（用 `NODE_USE_ENV_PROXY=1` 让 Node fetch 经 Clash 代理）。LiteLLM 注册 10 个 `copilot/*` 模型（claude-sonnet-4.6/opus-4.7/haiku-4.5、gpt-5.5/5.4/mini/4o、gemini-2.5/3.1、grok-code-fast）。端到端测试 `curl LiteLLM → copilot-api → Copilot Pro` 返回 "GATEWAY_OK"。范围变更见 ADR [[designs/2026-05-03-pivot-to-subscription-wrappers]]。
- 2026-05-03 · M0 部署完成（LiteLLM 1.83.14 跑在 127.0.0.1:4000，注册 7 个模型，master key 鉴权 OK）。部署形态从 Docker 切换到 uv venv（机器上无 Docker Desktop）。两个 CN Windows 编码坑：start.ps1 + config.yaml 改纯 ASCII，.env 里加 `PYTHONUTF8=1` 双保险。
- 2026-05-03 · 立项 + docs 脚手架。Office-hours 综合判断后否决"AI token 中转站业务"路径，转向 BYOA 自用聚合网关（v1 仅自用）。
