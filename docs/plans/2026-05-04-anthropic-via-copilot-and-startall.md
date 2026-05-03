---
status: done
project: AI-Gateway
type: plan
updated: 2026-05-04
milestone: M0.5c + M1.0
---

# M0.5c + M1.0：Claude Code 反代 Copilot Pro + 一键启停

> 现网部署链路 LiteLLM:4000 + copilot-api:4141 都能用 OpenAI 协议，但 Claude Code 是 Anthropic 协议（`/v1/messages`），需要打通。同时 bash background 进程会随会话死亡，需要可重入的启停脚本。

## 痛点

1. **Claude Code 用不上 Copilot Pro 流量** — Claude Code 通过 `ANTHROPIC_BASE_URL` 切端点，但请求是 Anthropic Messages API 格式；现网 LiteLLM 的 `copilot/*` 模型是 OpenAI provider 标记，`/v1/messages` 经过 LiteLLM 时会以 OpenAI 协议转发，copilot-api 收到的是错的 endpoint，404。
2. **进程持久化** — LiteLLM 和 copilot-api 都在 bash background 里跑（`b1164l9yw` / `bo80te665`），shell 一退就死。每次开机都要手起两次。

## 设计

### Anthropic 反代链路

关键观察：**copilot-api 原生支持 `/v1/messages` 端点**（输出标准 Anthropic SSE，含 streaming），不需要 LiteLLM 做协议转换。

策略：在 LiteLLM `config.yaml` 加一组 **anthropic provider** 模型条目，把 `api_base` 指向 `http://127.0.0.1:4141`，让 LiteLLM 用 Anthropic client passthrough 到 copilot-api 的 Anthropic endpoint。

```yaml
- model_name: claude-sonnet-4-6-copilot
  litellm_params:
    model: anthropic/claude-sonnet-4.6  # provider=anthropic, upstream model=4.6
    api_base: http://127.0.0.1:4141     # 指向 copilot-api 而非 api.anthropic.com
    api_key: dummy                       # copilot-api 不验证 key
```

命名约定：`claude-{tier}-{ver}-copilot`，与原来 OpenAI provider 的 `copilot/claude-{tier}-{ver}` 并存（前者给 Anthropic 客户端，后者给 OpenAI 客户端）。

新增 6 个：sonnet-4 / 4.5 / 4.6，opus-4.5 / 4.7，haiku-4.5（即 copilot-api 列表里的 Claude 全集）。

### 一键启停脚本

`scripts/start-all.ps1`：
- Idempotent：检测端口已 LISTEN 则 skip
- copilot-api 用 `powershell.exe -Command` 包装（.cmd 文件 Start-Process 直接调会失败）
- LiteLLM 复用现有 `start.ps1`
- e2e 健康检查：用 master key 调 `/v1/messages` 验证 `claude-sonnet-4-6-copilot` 链路

`scripts/stop-all.ps1`：按端口找 PID，Stop-Process -Force。

> NSSM 服务化（开机自启 + crash 自愈）留给 M1.5。

## 任务

- [x] config.yaml 加 6 个 `claude-*-copilot` 条目（anthropic provider）
- [x] 重启 LiteLLM 让新 config 生效
- [x] curl 验证 `/v1/messages` non-streaming + streaming 都通
- [x] 写 `scripts/start-all.ps1`（idempotent + e2e check）
- [x] 写 `scripts/stop-all.ps1`
- [x] 完整 stop → cold-start cycle 验证
- [x] README 更新：客户端接入说明 + 一键启停命令
- [x] CHANGELOG 加 entry
- [x] BACKLOG `进行中` 段移到 `已完成`

## 出口标准（已满足）

1. ✅ Claude Code 配 `ANTHROPIC_BASE_URL=:4000` + master key + `claude-sonnet-4-6-copilot` 能调通
2. ✅ Streaming SSE 完整（message_start → content_block_delta → message_stop）
3. ✅ `scripts\start-all.ps1` 一条命令拉起两服务并自检
4. ✅ `scripts\stop-all.ps1` 干净停止两服务

## 不在范围（推迟）

- ❌ NSSM 服务化（开机自启）→ M1.5
- ❌ supervisor 自愈（crash 自动重启）→ M1.5
- ❌ Claude Code 默认 model 别名映射（如 `claude-sonnet-4-5-20250929` → `claude-sonnet-4-5-copilot`）→ 等用户实际接入时按需做
