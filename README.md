# Sub2API 0.1.144（Linux amd64）

已内嵌前端；在线更新改为：确认 → 后台 git pull 标签对应的编译包 → 校验并替换程序 → 自动重启。版本弹窗显示进度及错误，下载失败不重启，不修改原端口、配置、数据库或密码。

本次必须同时更新 sub2api 与 git-update.sh，并重新运行安装器安装新版 helper。先备份数据库和配置，确认没有其他升级任务后执行：

```bash
cd /www/wwwroot/single-sub2api
git pull --ff-only
sudo bash install-ubuntu.sh upgrade -y --host 0.0.0.0 --port 9000
sudo systemctl status sub2api --no-pager
curl --fail http://127.0.0.1:9000/health
```

自定义服务名或安装目录要继续传原参数。此后网页确认更新会自动重启，沿用已有 systemd 端口。发布本版必须使用 v0.1.144 标签，不要移动旧标签。尚未替你 push、打标签或部署服务器。

查询故障：sudo journalctl -u sub2api -n 150 --no-pager。回滚只恢复上一版程序，不恢复数据库，回滚后仍需确认重启。
