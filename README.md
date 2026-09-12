# Sub2API 0.1.145（Linux amd64 / ARM64）

同一目录包含两种编译包：`sub2api` 供 x86_64/amd64，`sub2api-arm64` 供 aarch64/arm64。新版安装器和 Git 更新脚本自动选择，安装后的程序仍叫 sub2api，不要将 ARM64 程序覆盖到仓库的 amd64 文件上。

本版新增 `gpt-image-2.5-sunburst`、`gpt-image-2.5-flare` 及各自的 `-2026-09-08` 快照，补齐模型列表、白名单映射和价格目录。旧图片模型和默认值保留；实际调用需要上游账号具备对应模型权限。

用户 API Key 编辑弹窗新增“并发数量”：`0` 表示不限；设置为正数后，超过上限的请求立即返回 `429`，不排队。该限制按 API Key 独立计算，不会改变用户账号并发或上游账号并发。

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

两个程序内版本均为 0.1.145。将两个成品及脚本一并提交并 push，在同一提交上创建并推送新标签 v0.1.145，不移动旧标签。已安装新版多架构 helper 的服务器可在版本弹窗确认更新。旧标签若只有 amd64 文件，ARM64 在线更新会安全拒绝。尚未替你 push、打标签或部署服务器。

查询故障：sudo journalctl -u sub2api -n 150 --no-pager。回滚只恢复上一版程序，不恢复数据库，回滚后仍需确认重启。
