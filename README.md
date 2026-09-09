# Sub2API 0.1.144（Linux amd64 / ARM64）

同一目录包含两种编译包：`sub2api` 供 x86_64/amd64，`sub2api-arm64` 供 aarch64/arm64。新版安装器和 Git 更新脚本自动选择，安装后的程序仍叫 sub2api，不要将 ARM64 程序覆盖到仓库的 amd64 文件上。

已内嵌前端；在线更新改为：确认 → 后台 git pull 标签对应的编译包 → 校验并替换程序 → 自动重启。版本弹窗显示进度及错误，下载失败不重启，不修改原端口、配置、数据库或密码。

ARM64 服务器本次必须同步 `sub2api-arm64`、`install-ubuntu.sh` 和 `git-update.sh`，并重新运行安装器安装新版 helper，不能只上传 ARM64 二进制。先备份数据库和配置，确认没有其他升级任务后执行：

```bash
cd /www/wwwroot/single-sub2api
git pull --ff-only
sudo bash install-ubuntu.sh upgrade -y --host 0.0.0.0 --port 9000
sudo systemctl status sub2api --no-pager
curl --fail http://127.0.0.1:9000/health
```

9000 是示例端口，自定义端口、服务名或安装目录要继续传原参数，不传 --port 时安装器默认为 1122。此后网页确认更新会自动重启，沿用已有 systemd 端口。此次补充 ARM64 程序，版本仍为 0.1.144，不移动已发布的 v0.1.144 标签。以后发布新版本时，应在同一个新标签提交中包含两种架构且程序版本一致；旧标签若只有 amd64 文件，ARM64 在线更新会安全拒绝。尚未替你 push、打标签或部署服务器。

查询故障：sudo journalctl -u sub2api -n 150 --no-pager。回滚只恢复上一版程序，不恢复数据库，回滚后仍需确认重启。
