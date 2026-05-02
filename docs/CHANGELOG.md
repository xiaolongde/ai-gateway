# AI-Gateway CHANGELOG

## [Unreleased]

- 2026-05-03 · M0 部署完成（LiteLLM 1.83.14 跑在 127.0.0.1:4000，注册 7 个模型，master key 鉴权 OK）。部署形态从 Docker 切换到 uv venv（机器上无 Docker Desktop）。两个 CN Windows 编码坑：start.ps1 + config.yaml 改纯 ASCII，.env 里加 `PYTHONUTF8=1` 双保险。
- 2026-05-03 · 立项 + docs 脚手架。Office-hours 综合判断后否决"AI token 中转站业务"路径，转向 BYOA 自用聚合网关（v1 仅自用）。
