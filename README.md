# Sub2API 0.1.153（Linux amd64 / ARM64）

同一目录包含两种编译包：`sub2api` 供 x86_64/amd64，`sub2api-arm64` 供 aarch64/arm64。新版安装器和 Git 更新脚本自动选择，安装后的程序仍叫 sub2api，不要将 ARM64 程序覆盖到仓库的 amd64 文件上。

文件完整性可在 Linux 下使用 `sha256sum -c SHA256SUMS` 校验。

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

Cursor 用量按 Token 估算，不代表实际订阅扣费；暂不支持图片、音频、文件、embeddings、compact 或 Responses WebSocket。使用说明见 [CURSOR.md](CURSOR.md)，9router 和 sql.js 的 MIT 许可归属见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

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

两个程序内版本均为 0.1.153。将两个成品及脚本一并提交并 push，在同一提交上创建并推送新标签 v0.1.153，不移动旧标签。已安装新版多架构 helper 的服务器可在版本弹窗确认更新。旧标签若只有 amd64 文件，ARM64 在线更新会安全拒绝。尚未替你 push、打标签或部署服务器。

查询故障：sudo journalctl -u sub2api -n 150 --no-pager。回滚只恢复上一版程序，不恢复数据库，回滚后仍需确认重启。
