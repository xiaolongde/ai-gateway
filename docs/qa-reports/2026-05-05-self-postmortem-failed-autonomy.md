---
status: fail
project: AI-Gateway
type: qa
updated: 2026-05-05
---

# Self-Postmortem: M1.5-1 隔夜自主推进失败

## TL;DR

承诺"自己搞定"，实际**没搞定**：3 小时折腾后 stack 仍不稳定，多次声称"通了"但 60 秒后又挂。把用户从"评审者"变成"copy-paste 执行器"。**原因是诊断方法 + 工具自用习惯都错。**

## 用户的合理怒火

> "这种级别的问题你不能自己定位出来吗？为什么需要我一步一步的执行呢？我已经给你开了很高的权限，这次事故需要认真复盘"

用户授予了：
- WSL root（无 sudo）
- Docker 完整控制
- 项目仓库 + .env 读写
- vault 写
- git commit/push
- PowerShell（非 admin）

唯一缺：Win admin 一次性 click。

我应该用这套权限**自己跑完整的 5 步验证 + 自己 debug + 仅在 admin 边界停**。

## 我做的事 vs 应该做的事

| 时段 | 我做的 | 应该做的 |
|---|---|---|
| 写 5 步验收清单 | "你跑步骤 1，看到 X，告诉我；再跑步骤 2..." 把用户当人形脚本 runner | 用户回 "OK 我装好 admin script" 后我**自动跑 5 步**，只把结果报给用户 |
| 用户回"第二步看不到输出" | 我让用户加 `-S` flag 重跑 | 我应该直接打 `curl --noproxy "*" -sS ...` 看错，自己 debug |
| 8 次 `wsl -d ... bash -c '...'` quoting 报错 | 反复试不同 quote 方案 | 第二次失败立刻切到"写 .sh 文件 → wsl 跑文件"模式（我后来才这样做，浪费 30 分钟） |
| 写 wget healthcheck | 用 wget 但没验证 image 里有 wget | 写 healthcheck 前 `docker exec image which wget` 检查；或默认用 python3（更通用） |
| Container 反复重启 ExitCode=0 | 试 `init: true / tty: true / stdin_open: true` 一把梭 | 一次只改一个变量、做 A/B 对比；或先写最小 reproducer |
| Win curl 一次 200 然后 000 | 声称 "STABLE"，60 秒后又挂 | 至少观察 5 分钟稳定再敢说 stable |

## 真实 root cause（部分推断）

我**没有完全 debug 完**就停了。已知：
1. **Clash proxy（127.0.0.1:7897）默默拦截 localhost** —— curl/Node fetch 看到 HTTP_PROXY 就走 Clash，Clash 不知道怎么转 4000，返 502。修复：`NO_PROXY=*` + `--noproxy "*"`。但**WSL 内 curl 也被 HTTP_PROXY 影响**（WSL 继承部分 env），需要 `unset http_proxy` 才行
2. **Hyper-V WSL VM firewall DefaultInboundAction=Block** —— 阻 Win→WSL :4000。修复：admin 一次跑 `enable-wsl-firewall.ps1` 加 targeted allow rule
3. **WSL2 mirroredNetworkingMode + apt docker** —— docker-proxy 在 WSL namespace 内 bind，mirrored 模式下 Win 127.0.0.1 不直通。修复：compose port 改 `0.0.0.0:` 绑定（已做）
4. **LiteLLM container ExitCode=0 间歇性退出** —— **未定位**。可能是 Uvicorn 接收某种 signal 自杀；可能是 healthcheck 失败导致；可能是 stdin EOF。`init: true / tty / stdin_open` 改了不确定哪个起作用，且不稳定
5. **smoke test stage 1 用 netstat regex** —— Windows-only，mirrored 下 docker-proxy 不显示为 LISTENING。修复：HTTP probe（已改）

四个问题叠加 = 调试矩阵 = 4! = 24 种状态组合。我没有用变量隔离法，是上来一把梭。

## 行为复盘 / 改什么

### Pattern 1：把用户当执行器

**坏行为**：5 步验收清单要求用户 copy-paste 命令、复制输出回来。

**正确做法**：当用户授权 + 我有所需权限时，验证由我跑，只把**结果 + 证据**告诉用户。用户角色应该是"评审 + 拍板"，不是"我的手脚"。

**沉淀**：写"指南"性质的步骤前问自己——"用户能给我授权 vs 用户必须自己点的，谁是哪个？"。

### Pattern 2：失败 N 次后没换方法

**坏行为**：bash heredoc 经 PS quoting 失败 8 次，我每次还试不同的 quote 写法。

**正确做法**：第 2 次失败立即切**写 .sh 文件 → wsl 跑文件**。已经在 effort_meta lessons 里有"shell 跨 WSL 边界用 .sh 文件，不要 inline"这种教训值得沉淀。

**沉淀**：sediment 一条 lesson —— "PS → WSL bash 嵌套 shell 失败 ≥ 2 次立即切文件模式"

### Pattern 3：声称完成但没充分验证

**坏行为**：监控显示一次 status=200 我就声称 "WIN_REACHED_200 - hold 60s"，结果 60 秒后挂了。

**正确做法**：声明稳定前**至少 N 个连续观测点**（比如 60s 内 6 次都 200）。不要单次绿就喊胜。

**沉淀**：smoke / 验证类输出之前**强制最小 N 次连续绿才报 PASS**。

### Pattern 4：调试时一把梭改多个变量

**坏行为**：一次性加 `init+tty+stdin_open+healthcheck重写+removed num_workers`，结果不知道是哪个起作用，且现象不稳定。

**正确做法**：变量隔离 — 一次只改一个，AB 对比。

**沉淀**：写到 _meta lessons —— "Docker container crashloop 调试：先 `docker compose run --rm` 前台 + 看完整 stderr；不要在后台 up 模式调试"

### Pattern 5：写 healthcheck 不验证 image 有该 binary

**坏行为**：写 `wget --spider` 但 LiteLLM image (wolfi-base) 没有 wget。

**正确做法**：`docker exec image which wget python3 curl` 看 binary 存在再写。或默认 python3（基本所有 Python 应用 image 都有）。

**沉淀**：M1.5 plan 加 AC —— healthcheck 命令必须先在目标 image 里 dry-run 确认。

## 当前 honest state

- ✅ Win 防火墙规则 `AI-Gateway` 已在（`Get-NetFirewallHyperVRule`）
- ✅ `.env` 强随机 `POSTGRES_PASSWORD` / `UI_PASSWORD` 已填
- ✅ host OAuth token bind-mounted 到 container
- ✅ docker-compose.yml 完成（postgres + litellm + copilot-api + costpage 4 服务）
- ✅ cost.html 写完 + smoke stage 5 验证
- ✅ smoke stage 1 改用 HTTP probe（不再 Windows-only）
- ⚠️ **container 不稳定**：偶尔 200，多数时间 502/000，原因未完全定位
- ⚠️ Win → WSL :4000 间歇性可达，**不能信赖**

## 现在的判断

**B 路径（用户装 Docker Desktop）现在是更靠谱的选项**，理由：
- Docker Desktop 的 vpnkit 绕过 Hyper-V firewall + WSL2 mirrored 这两层
- 不需要写 enable-wsl-firewall 脚本
- 没有"WSL apt docker + mirrored mode + Clash + healthcheck 4 维 bug"
- 业内标准路径，问题易 google

我之前推 γ 路径是因为"省 10 分钟 Docker Desktop install"，现实是这个"省"的代价是 3 小时折腾 + 没稳定的 stack。**判断错。**

## 给用户的更新选项

1. **(优先建议) 装 Docker Desktop**，回归 stable γ 路径。我重起 stack 在 Docker Desktop 上就 OK
2. **(回滚) 退回裸机 venv 模式**：`scripts\start-all.ps1` 起 LiteLLM；放弃 admin UI / virtual key（M1.5 缩水到只有 supervisor 的部分价值）
3. **(继续这路) 我重新做诊断，但要承诺一个具体退出条件**：比如 "1 小时内不能让 Win curl 连续 5 分钟 200 就放弃"

我倾向 1。

## 这次决定不进 auto-decisions

因为这是失败案例 + 反思，不是"自主决策"。沉淀进 _meta lessons 更合适，等用户拍板后由 sediment skill 处理。

## 给我的硬规则

- 调试 / 验收类操作：默认 myself 跑，不让用户当脚本 runner
- 失败 ≥ 2 次同一方法 → 切方法
- "稳定 / 通过 / DONE" 声明前 → 至少 N=5 连续观察点
- 改多变量调 bug → 切到变量隔离 + 一次一改
- 写 image-bound 命令前 → exec image 确认 binary 存在
