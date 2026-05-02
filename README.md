# AI-Gateway

> 个人 BYOA AI 统一网关。基于 LiteLLM Proxy。**v1 仅自用，不对外。**

设计与计划见 `docs/`：
- 设计：[docs/designs/2026-05-03-design.md](docs/designs/2026-05-03-design.md)
- M0 计划：[docs/plans/2026-05-03-mvp-litellm-deploy.md](docs/plans/2026-05-03-mvp-litellm-deploy.md)
- 状态：[docs/state.md](docs/state.md)

## 启动（首次）

```powershell
# 1. 安装依赖（uv 管 venv）
uv sync

# 2. 填 .env 里的上游 API key
#    至少填 ANTHROPIC_API_KEY；其他可选
notepad .env

# 3. 启动
.\start.ps1
```

启动后：

- 端点：`http://127.0.0.1:4000`
- Master key：见 `.env` 里的 `LITELLM_MASTER_KEY`
- Health check：`curl http://127.0.0.1:4000/health/liveness`

## 客户端配置（下游工具切到网关）

### Claude Code
```powershell
$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:4000"
$env:ANTHROPIC_AUTH_TOKEN = "<你的 LITELLM_MASTER_KEY>"
```

### Cursor / 任何 OpenAI 兼容客户端
- Base URL: `http://127.0.0.1:4000/v1`
- API key: `<你的 LITELLM_MASTER_KEY>`
- Model: 选 config.yaml 里定义的 `model_name`（如 `claude-sonnet-4-6` / `deepseek-chat`）

## 模型清单（见 config.yaml）

| 客户端模型名 | 上游 |
|------|------|
| claude-sonnet-4-6 | Anthropic |
| claude-opus-4-7 | Anthropic |
| claude-haiku-4-5 | Anthropic |
| gpt-4o / gpt-4o-mini | OpenAI |
| deepseek-chat / deepseek-reasoner | DeepSeek |

## 三道铁律（详见 CLAUDE.md）

1. 绝不对外
2. 绝不造轮子
3. M0 7 天死线（2026-05-10）
