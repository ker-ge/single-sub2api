# Sub2API 0.1.161（Linux amd64 / ARM64）

同一目录包含两种编译包：`sub2api` 供 x86_64/amd64，`sub2api-arm64` 供 aarch64/arm64。新版安装器和 Git 更新脚本自动选择，安装后的程序仍叫 sub2api，不要将 ARM64 程序覆盖到仓库的 amd64 文件上。

文件完整性可在 Linux 下使用 `sha256sum -c SHA256SUMS` 校验。

## 0.1.161 更新

- 修复 Astra 等主模型使用 `xhigh` / `max` / `ultra` 生图时，图片工具复杂度与主模型推理强度冲突的问题；GPT Image 2.6 和未指定型号的原生生图工具独立设置 `complexity`。
- 保留主模型推理档位及图片工具显式指定的 `low` / `medium` / `high`，图片复杂度中的 `xhigh` / `max` / `ultra` 转为 `high`；旧图片模型及 `quality` 画质参数保持原样。
- 覆盖 HTTP、WebSocket、透传和多轮请求；直接以图片模型调用 Responses 时，将顶层 `complexity` 转交给图片工具。

## 0.1.160 更新

- 新增 Codex HTTP / WebSocket 配置中的模型和推理强度选择，Ultra 支持 GPT-6 Astra、GPT-6.1 Sol、GPT-6.1 Terra、GPT-6 Sol、GPT-5.6 Sol 和 GPT-5.6 Terra；Luna 不提供 Ultra。
- 网关按映射后的上游模型转换 Ultra：Astra、6.1 Sol、6.1 Terra 使用 `xhigh`，6 Sol、5.6 Sol、5.6 Terra 使用 `max`；显式推理强度优先，并补齐别名计费及 OpenCode 配置。
- 修复 `/v1/messages` 的账号别名映射与调度联动，优先精确映射，保留基础模型回退并按实际映射目标检查渠道限制。
- 修复 WebSocket 多轮请求的计费模型及参数串用，重叠请求不再覆盖当前响应；有效二进制 JSON 结束事件正常结算并解除忙碌状态，支持后续请求和请求被拒后的重试。

Ultra 的完整子代理协作由支持该模式的 Codex 客户端提供；网关别名及 OpenCode 选项只转换推理参数。实际可用性取决于客户端版本和上游账号权限。

## 0.1.159 更新

- 新增 OpenAI `gpt-image-2.6-sunburst`（精细画面与编辑）和 `gpt-image-2.6-flare`（快速生成与迭代），同步默认模型列表、账号白名单、快捷映射和价格目录。
- GPT Image 1.5 从默认列表和预设中移除，保留旧账号配置及历史计费数据；GPT Image 2/2.5 继续保留，未指定图片模型时仍使用 `gpt-image-2`。
- 两款 2.6 模型优先使用精确匹配的动态价格，远程目录尚未收录时使用官方兜底价，避免套用旧型号价格。

标准价格为每百万 Token 文本输入 5、文本缓存读取 1.25、图片输入 8、图片输出 30 美元。图片缓存独立计费、SVG/GIF 专用计费及 OAuth 的新增图片参数转换未扩展。

已有账号设置了白名单时，需勾选新模型并保存。图片生成和编辑可使用 `/v1/images/generations`、`/v1/images/edits`；实际可用性由上游账号权限决定。官方依据：[Sunburst](https://developers.openai.com/api/docs/models/gpt-image-2.6-sunburst)、[Flare](https://developers.openai.com/api/docs/models/gpt-image-2.6-flare)、[价格表](https://developers.openai.com/api/docs/pricing#image-generation)（2026-11-05 核对）。

## 0.1.158 更新

- 新增 OpenAI `gpt-6.1-terra`，同步模型列表、账号白名单、快捷映射、批量测试顺序和 OpenCode 配置；支持 `none`、`low`、`medium`、`high`、`xhigh`、`max` 思考档位。
- 补齐标准、Fast / Priority、Flex 价格和超过 272K 输入 Token（含缓存）的长上下文计费；上下文窗口为 1,050,000 Token，最大输出 128,000 Token。
- 修复 `/v1/messages` 转发 `gpt-6.1-terra-none` 时被默认 `medium` 覆盖的问题，OAuth 和 API Key 路径均保留 `none`，显式设置的思考强度优先。

标准价格为每百万 Token 输入 1、输出 5、缓存读取 0.05、30 分钟缓存写入 1.25 美元。Fast / Priority 为 2 倍，Flex 为 0.5 倍；输入总量超过 272K 时，整次请求的输入和缓存为 2 倍、输出为 1.5 倍。12 小时缓存写入和区域处理附加费未新增独立计费。

已有账号设置了白名单时，需勾选新模型并保存；上游账号仍需具备模型权限。工具调用使用 Responses 接口。模型及价格依据 [OpenAI 官方模型页](https://platform.openai.com/docs/models/gpt-6.1-terra/)（2026-10-27 核对）。

## 0.1.157 更新

- Claude 请求统一使用可配置的全局 UA，覆盖转发、授权、令牌刷新、模型同步、用量查询和账号测试；新增 Claude Code 官方稳定版自动同步，内置基线为 `claude-cli/2.1.258 (external, cli)`，手动 UA 优先。
- 新增 Claude OAuth 自动刷新，后台检查和请求时兜底共用刷新协调器；避免并发刷新、旧 401 和账号编辑覆盖新令牌，保留独立冷却与手动调度设置。
- 完善 Responses / Chat Completions 桥接，支持命名空间函数、custom 工具、tool_search 动态声明、旧版消息和函数调用历史、内嵌 PDF、结构化输出及 Claude 5.5 思考签名兼容。
- 修复流式工具参数拼接、异常结束、读超时和客户端断开后的用量收集；失败请求按上游已报告用量记录，保留缓存 Token 明细。
- 对齐 billing 指纹、停用 CCH 签名，完善 Beta 字段处理和缓存 TTL 顺序；原生 Messages 的 Opus Fast 模式按有效档位计费，新增上游响应模型审计。
- Fable 独立额度和冷却与共享窗口联动，账号用量新增 `7d F`，并保护较新的主动/被动采样结果。

Claude UA 和版本自动同步位于「系统设置 → 网关 → 请求转发行为」。自动同步默认开启，关闭后保留最后同步值；手动 UA 留空并保存后跟随同步版本。OAuth 自动续期需要已保存 Refresh Token，只有 Access Token 的账号无法自动续期。

## 0.1.156 更新

- 新增 Claude Opus 5.5、Sonnet 5.5、Haiku 5.5，完善 Fable 5.1 支持；同步模型列表、白名单、映射和价格，修复兼容接口的参数转换及 Haiku 长上下文计费。
- 新增 Gemini 4 Argon、3.8 Flash、3.5 Flash-Lite、Nano Banana 2.1 和 Nano Banana 2 Lite；同步模型选择、账号测试及价格，适配映射后的模型参数、思考强度和工具调用 ID。
- Gemini 图片模型支持原生接口生成图片和账号测试预览；修复实际图片数量计费、默认尺寸、价格别名、countTokens 误计图片费用，以及流式响应的图片和文本顺序、签名与候选结果保留。
- Gemini 密钥检测仅在确认密钥无效时禁用账号，避免将模型无权限等错误误判为密钥失效。

已有账号设置了模型白名单时，需勾选新模型并保存。图片生成使用 Gemini 原生 `generateContent` 或 `streamGenerateContent` 接口，并设置 `generationConfig.responseModalities` 为 `["TEXT", "IMAGE"]`；模型权限仍由上游账号决定。

本地兜底价格中，Gemini 4 Argon 的促销价有效至 2026-11-30，3.8 Flash 有效至 2026-12-31；离线部署需在到期前更新价格目录，本地兜底不会按日期自动切换。

## 0.1.155 更新

- 新增独立 Grok 平台、账号和分组，支持 xAI API Key、Grok OAuth、授权链接登录、令牌自动刷新及重新授权。
- Grok 支持 Chat Completions、Responses、Anthropic Messages 的文本、函数工具调用、流式及非流式响应；支持模型同步、多选移除、模型定价和用量统计。
- 修复 Grok 凭证更新与刷新并发时的覆盖、重新授权与调度状态联动、流式失败处理、用量记录及慢客户端误判上游超时的问题。
- Grok 账号类型改为与 OpenAI 一致的双列卡片，支持暗色模式和键盘选择；修复 Cursor 分组平台展示及相关联动。

使用 Grok 前，在设置的平台展示中勾选 **Grok**，再创建 Grok 分组和账号。默认展示仍为 OpenAI、Anthropic。

OAuth 登录后，将浏览器地址栏中的完整 `http://127.0.0.1:56121/callback?code=...&state=...` 地址粘贴回账号页面完成授权；服务器无需安装 Grok CLI。授权会话有效期为 30 分钟，服务重启后需重新生成链接。API Key 默认连接 `https://api.x.ai/v1`，OAuth 默认连接 `https://cli-chat-proxy.grok.com/v1`。

Grok 当前支持文本与函数工具调用；尚未适配图片、视频、音频、文件输入、服务端搜索等内置工具、WebSocket 和 `responses/compact`。模型权限以账号实际可用范围为准，新同步的未知模型需配置价格；实际 xAI/Grok 账号的授权与推理仍需上线后验证。

## 0.1.153 更新

- 本地通过 localhost、127.0.0.1 或 [::1] 访问且 API 同样位于本机时，新增 Cursor 账号自动读取 Access Token 和 Machine ID；编辑账号需主动点击重新检测。
- 服务器部署支持从访问者电脑授权选择 Cursor 数据目录，在浏览器内解析并填入凭证，无需本机 Sub2API 或额外检测工具，目录和数据库不会上传。
- 修复 Chrome/Edge 禁止目录授权接口访问 AppData 等系统目录后无法继续的问题；“手动选择目录”可直接使用备用选择器。手动选择前请完全退出 Cursor。
- 检测期间锁定账号保存，失败、取消或手动编辑时保留已有输入；关闭弹窗中止读取。检测到未合并的数据库日志时拒绝填入可能过期的凭证。

## 0.1.152 更新

- 新增独立 Cursor 平台、账号和分组，支持 Chat Completions、Responses、Anthropic Messages 的文本、工具调用及流式响应；Cursor 与 OpenAI 账号调度隔离。
- 平台展示可配置，默认展示 OpenAI、Anthropic，OpenAI 排在第一；账号、分组及相关选择器同步联动。
- Cursor 新增账号可自动读取服务所在电脑的 Access Token 和 Machine ID，编辑账号可点击重新读取。支持 Windows、macOS、Linux 常见路径；远程服务器无法直接读取浏览器所在电脑的凭证。
- Cursor 模型列表从上游动态同步，支持搜索、多选、逐项删除和一键清除，保存后生效。空白名单表示允许该账号支持的全部模型。
- Cursor 可用模型随账号及网络出口变化。若 IDE 能看到 Claude/GPT 而同步列表没有，请给账号配置与 IDE 一致的代理并保存后重新同步；服务器需使用自身可访问的代理，不能照搬本地 `127.0.0.1:1080`。

Cursor 用量按 Token 估算，不代表实际订阅扣费；暂不支持图片、音频、文件、embeddings、compact 或 Responses WebSocket。

保留 0.1.151 的 OpenAI User-Agent 统一设置、API Key 并发限制及 `gpt-6.1-sol` 支持。

已内嵌前端；在线更新改为：确认 → 后台 git pull 标签对应的编译包 → 校验并替换程序 → 自动重启。版本弹窗显示进度及错误，下载失败不重启，不修改原端口、配置、数据库或密码。

若服务器尚未安装多架构更新脚本，需同步对应二进制、`install-ubuntu.sh` 和 `git-update.sh`，并重新运行安装器一次，不能只上传二进制。先备份数据库和配置，确认没有其他升级任务后执行（当前 ARM64 服务器端口为 1122）：

```bash
cd /www/wwwroot/single-sub2api
git pull --ff-only
sudo bash install-ubuntu.sh upgrade -y --host 0.0.0.0 --port 1122
sudo systemctl status sub2api --no-pager
curl --fail http://127.0.0.1:1122/health
```

其他服务器必须继续传原端口、服务名和安装目录，例如原端口为 9000 时使用 --port 9000。不传 --port 时安装器默认为 1122。系统和云防火墙均须放行所用 TCP 端口。网页确认更新会自动重启，沿用已有 systemd 端口。

两个程序内版本均为 0.1.161。将两个成品、脚本、说明及 SHA256SUMS 一并提交并 push，在同一提交上创建并推送新标签 v0.1.161，不移动旧标签。已安装新版多架构 helper 的服务器可在版本弹窗确认更新。旧标签若只有 amd64 文件，ARM64 在线更新会安全拒绝。尚未替你 push、打标签或部署服务器。

查询故障：sudo journalctl -u sub2api -n 150 --no-pager。回滚只恢复上一版程序，不恢复数据库，回滚后仍需确认重启。
