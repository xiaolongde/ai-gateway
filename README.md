# AI-Gateway

> Personal BYOA AI gateway. Two-layer: LiteLLM (API router) + copilot-api (subscription wrapper). **v1: self-use only.**

设计 + 计划在 `docs/`：
- 主设计：[docs/designs/2026-05-03-design.md](docs/designs/2026-05-03-design.md)
- ADR (M2→M0 范围变更): [docs/designs/2026-05-03-pivot-to-subscription-wrappers.md](docs/designs/2026-05-03-pivot-to-subscription-wrappers.md)
- M0 计划：[docs/plans/2026-05-03-mvp-litellm-deploy.md](docs/plans/2026-05-03-mvp-litellm-deploy.md)
- 状态：[docs/state.md](docs/state.md)

## 架构

```
[Claude Code] ┐
[Cursor]      ├→ LiteLLM (127.0.0.1:4000)  ┬→ Anthropic / OpenAI / DeepSeek (need own key)
[scripts]     ┘                             └→ copilot-api (127.0.0.1:4141) → GitHub Copilot Pro
```

客户端只看到 LiteLLM。Copilot Pro 订阅经 `copilot-api` 暴露成 OpenAI/Anthropic 兼容端点，纳入 LiteLLM 做 upstream。

## 启动（首次）

```powershell
# 1. 装 LiteLLM venv
uv sync

# 2. 装 copilot-api（全局 npm 包）
npm install -g copilot-api

# 3. GitHub OAuth 授权 Copilot Pro
$env:NODE_USE_ENV_PROXY = "1"   # 如果在 GFW 区域且有 HTTP_PROXY
copilot-api auth

# 4. 填 .env（LITELLM 自身已自动生成强随机 master key；上游 API key 按需填）
notepad .env

# 5. 启 LiteLLM（前台）
.\start.ps1

# 6. 在另一个窗口启 copilot-api（前台）
copilot-api start --port 4141 --account-type individual
```

## 端点

- **客户端调用**：`http://127.0.0.1:4000`
- **Master key**：见 `.env` 里 `LITELLM_MASTER_KEY`

## 17 个可用模型（截至 2026-05-03）

### 直连 API（按 token 计费，需自己 key）
| model_name | upstream |
|------|------|
| `claude-sonnet-4-6` / `claude-opus-4-7` / `claude-haiku-4-5` | Anthropic API（需 ANTHROPIC_API_KEY）|
| `gpt-4o` / `gpt-4o-mini` | OpenAI API（需 OPENAI_API_KEY）|
| `deepseek-chat` / `deepseek-reasoner` | DeepSeek API（需 DEEPSEEK_API_KEY）|

### 经 Copilot Pro（已纳入 $39.9/mo 订阅，无额外计费）
| model_name | 上游真名 |
|------|------|
| `copilot/claude-sonnet-4.6` / `copilot/claude-opus-4.7` / `copilot/claude-haiku-4.5` | Anthropic via Copilot |
| `copilot/gpt-5.5` / `5.4` / `5-mini` / `4o` | OpenAI via Copilot |
| `copilot/gemini-2.5-pro` / `3.1-pro-preview` | Google via Copilot |
| `copilot/grok-code-fast-1` | xAI via Copilot |

> Copilot 上游全部 42 模型可见 `curl http://127.0.0.1:4141/v1/models`，按需在 `config.yaml` 加更多 `copilot/*` 条目。

## 客户端切换

### Claude Code
```powershell
$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:4000"
$env:ANTHROPIC_AUTH_TOKEN = "<LITELLM_MASTER_KEY>"
# 模型自动用 claude-sonnet-4-6 / claude-opus-4-7（Claude Code 默认）
# 想用 Copilot Pro 通道的话设置：
$env:ANTHROPIC_MODEL = "copilot/claude-sonnet-4.6"
```

### Cursor / OpenAI 兼容客户端
- Base URL: `http://127.0.0.1:4000/v1`
- API key: `<LITELLM_MASTER_KEY>`
- Model: 选上面表格里任一 `model_name`

## 三道铁律（详见 CLAUDE.md）

1. **绝不对外** — 即使朋友想付费也拒绝
2. **绝不造轮子** — 用 LiteLLM + copilot-api 现成项目
3. **MVP 7 天死线** — 2026-05-10
