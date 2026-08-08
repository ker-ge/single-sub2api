# Sub2API Ubuntu 直连部署包

本目录是适用于 Ubuntu 的 Linux amd64 发布包。`sub2api` 二进制已经内置前端，安装脚本会创建 systemd 服务并直接对外提供访问，不需要安装 Nginx、Go、Node.js、pnpm，也不需要配置反向代理。

## 包含文件

- `sub2api`：Linux amd64 编译好的程序
- `install-ubuntu.sh`：Ubuntu 安装、升级、卸载和运维脚本

## 安装

在本目录执行：

```bash
sudo bash install-ubuntu.sh install -y --open-firewall
```

默认监听地址为 `0.0.0.0:1122`，浏览器访问：

```text
http://服务器公网IP:1122
```

请使用 `http://`，不要直接使用 `https://`。另外还需要在云服务器控制台的安全组/入站规则中放行 TCP `1122`。

自定义监听地址或端口：

```bash
sudo bash install-ubuntu.sh upgrade -y --host 0.0.0.0 --port 9000
```

如果服务器之前使用的是 `8080`，切换到当前默认端口时执行：

```bash
sudo bash install-ubuntu.sh upgrade -y --host 0.0.0.0 --port 1122 --open-firewall
```

## 服务管理

```bash
sudo bash install-ubuntu.sh status
sudo bash install-ubuntu.sh restart
sudo bash install-ubuntu.sh logs
```

也可以使用 systemd 命令：

```bash
sudo systemctl status sub2api --no-pager
sudo journalctl -u sub2api -f
sudo systemctl restart sub2api
```

## 文件和数据位置

- 程序：`/opt/sub2api/sub2api`
- 配置：`/opt/sub2api/config.yaml`
- 服务环境变量：`/etc/sub2api/sub2api.env`
- 数据库：`/opt/sub2api/data/sub2api.db`
- 备份：`/opt/sub2api/backups`

系统安装了 `sqlite3` 时，脚本会自动启用每日 SQLite 备份定时器。

## 故障排查

检查服务是否监听 1122：

```bash
sudo ss -lntp | grep ':1122'
curl -i http://127.0.0.1:1122/
```

如果本机 `curl` 返回 `HTTP/1.1 200 OK`，但浏览器仍然无法访问，请检查云服务器安全组是否放行 TCP `1122`。UFW 可以使用以下命令放行：

```bash
sudo ufw allow 1122/tcp
```

默认管理员账号：

```text
邮箱：123456@admin.com
密码：123456
```

首次登录后请立即修改密码。

## 卸载

保留数据库、配置和备份：

```bash
sudo bash install-ubuntu.sh uninstall
```

同时删除服务、程序和所有数据：

```bash
sudo bash install-ubuntu.sh uninstall --purge
```
