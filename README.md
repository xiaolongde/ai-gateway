# AI-Gateway

> Personal BYOA AI gateway. Two-layer: LiteLLM (API router) + copilot-api (subscription wrapper). **v1: self-use only.**

设计 + 计划在 `docs/`：
- 主设计：[docs/designs/2026-05-03-design.md](docs/designs/2026-05-03-design.md)
- ADR (M2→M0 范围变更): [docs/designs/2026-05-03-pivot-to-subscription-wrappers.md](docs/designs/2026-05-03-pivot-to-subscription-wrappers.md)
- M0 计划：[docs/plans/2026-05-03-mvp-litellm-deploy.md](docs/plans/2026-05-03-mvp-litellm-deploy.md)
- M0.5c+M1.0：[docs/plans/2026-05-04-anthropic-via-copilot-and-startall.md](docs/plans/2026-05-04-anthropic-via-copilot-and-startall.md)
- 状态：[docs/state.md](docs/state.md)

## 架构

```
[Claude Code]   ┐                                     ┌→ Anthropic / OpenAI / DeepSeek (need own key)
                ├→ LiteLLM (127.0.0.1:4000) ──────────┤
[Cursor / API]  ┘   /v1/messages   /v1/chat/...       └→ copilot-api (127.0.0.1:4141) → GitHub Copilot Pro
```

LiteLLM 同时暴露 Anthropic Messages API (`/v1/messages`) 和 OpenAI Chat Completions (`/v1/chat/completions`)，所有客户端流量统一在 :4000 鉴权。Copilot Pro 订阅经 `copilot-api` 暴露成兼容端点，纳入 LiteLLM 做 upstream。

## 一键启停

```powershell
# 拉起两服务（idempotent，已起则 skip + 自动 e2e 健康检查）
.\scripts\start-all.ps1

# 停掉
.\scripts\stop-all.ps1
```

> 进程目前仍随启动它的 PowerShell 窗口生命周期；开机自启 / crash 自愈见 M1.5（NSSM 服务化）。

## 启动（首次）

```powershell
# 1. 装 LiteLLM venv
uv sync

# 2. 装 copilot-api（全局 npm 包）
npm install -g copilot-api

# 3. GitHub OAuth 授权 Copilot Pro
$env:NODE_USE_ENV_PROXY = "1"   # 在 GFW 区域且有 HTTP_PROXY 时启用
copilot-api auth

# 4. 填 .env（LITELLM master key 已自动生成；上游 API key 按需填）
notepad .env

# 5. 一键拉起
.\scripts\start-all.ps1
```

## 端点

- **客户端调用**：`http://127.0.0.1:4000`
- **Master key**：见 `.env` 里 `LITELLM_MASTER_KEY`
- **Anthropic 协议入口**：`POST /v1/messages`（Claude Code）
- **OpenAI 协议入口**：`POST /v1/chat/completions`（Cursor 等）

## 可用模型（截至 2026-05-04，共 23 个）

### 直连 API（按 token 计费，需自己 key）
| model_name | upstream |
|------|------|
| `claude-sonnet-4-6` / `claude-opus-4-7` / `claude-haiku-4-5` | Anthropic API（需 ANTHROPIC_API_KEY）|
| `gpt-4o` / `gpt-4o-mini` | OpenAI API（需 OPENAI_API_KEY）|
| `deepseek-chat` / `deepseek-reasoner` | DeepSeek API（需 DEEPSEEK_API_KEY）|

### 经 Copilot Pro · OpenAI 协议（给 Cursor 等）
| model_name | 上游 |
|------|------|
| `copilot/claude-sonnet-4.6` / `copilot/claude-opus-4.7` / `copilot/claude-haiku-4.5` | Anthropic via Copilot |
| `copilot/gpt-5.5` / `5.4` / `5-mini` / `4o` | OpenAI via Copilot |
| `copilot/gemini-2.5-pro` / `3.1-pro-preview` | Google via Copilot |
| `copilot/grok-code-fast-1` | xAI via Copilot |

### 经 Copilot Pro · Anthropic 协议（给 Claude Code）
| model_name | 上游 |
|------|------|
| `claude-sonnet-4-copilot` / `claude-sonnet-4-5-copilot` / `claude-sonnet-4-6-copilot` | via Copilot |
| `claude-opus-4-5-copilot` / `claude-opus-4-7-copilot` | via Copilot |
| `claude-haiku-4-5-copilot` | via Copilot |

> Copilot 上游全部 42 模型可见 `curl http://127.0.0.1:4141/v1/models`，按需在 `config.yaml` 加更多条目。

## 客户端切换

### Claude Code（走 Copilot Pro 流量，0 token 计费）
```powershell
$env:ANTHROPIC_BASE_URL  = "http://127.0.0.1:4000"
$env:ANTHROPIC_AUTH_TOKEN = "<LITELLM_MASTER_KEY>"
$env:ANTHROPIC_MODEL      = "claude-sonnet-4-6-copilot"   # 或 -opus-4-7- / -haiku-4-5-copilot
```

### Claude Code（走 Anthropic API 直连，按 token 计费）
```powershell
$env:ANTHROPIC_BASE_URL  = "http://127.0.0.1:4000"
$env:ANTHROPIC_AUTH_TOKEN = "<LITELLM_MASTER_KEY>"
$env:ANTHROPIC_MODEL      = "claude-sonnet-4-6"           # 不带 -copilot 后缀
# 需在 .env 填 ANTHROPIC_API_KEY=sk-ant-...
```

### Cursor / OpenAI 兼容客户端
- Base URL: `http://127.0.0.1:4000/v1`
- API key: `<LITELLM_MASTER_KEY>`
- Model: 选上面表格里任一 `model_name`（推荐 `copilot/*` 走订阅免计费）

## 三道铁律（详见 CLAUDE.md）

1. **绝不对外** — 即使朋友想付费也拒绝
2. **绝不造轮子** — 用 LiteLLM + copilot-api 现成项目
3. **MVP 7 天死线** — 2026-05-10
