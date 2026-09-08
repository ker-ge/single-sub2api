# Sub2API 0.1.139 上线包

平台：Linux amd64 / x86_64（Ubuntu + systemd）。程序已内嵌前端，无需 Go、Node、Docker 或单独部署网页。

## 本次包含

- Git 标签在线更新：使用 ker-ge/single-sub2api 成品仓库，不依赖 Release 或 GitHub Actions。
- 更新时固定标签对应的提交，验证 Git 对象、CPU 架构和程序内版本，保留上一版程序。
- 管理后台确认更新、重启和程序回滚。
- 新版二进制安装器及本地 Git 更新脚本。
- 修正安装完成后的密码提示：升级保留原账号密码，不会重置成 123456。

## 你的服务器：9000 端口

先独立备份现有安装目录和数据库。将本包内所有文件上传到成品工作目录，例如 /www/wwwroot/single-sub2api。不要删除这个目录里的 .git，也不要上传或替换现有数据库和配置。

在服务器执行：

```bash
cd /www/wwwroot/single-sub2api
uname -m
sha256sum -c SHA256SUMS
chmod +x sub2api install-ubuntu.sh git-update.sh
./sub2api -version
sudo bash install-ubuntu.sh upgrade -y --host 0.0.0.0 --port 9000
sudo systemctl status sub2api --no-pager
curl --fail http://127.0.0.1:9000/health
```

uname -m 必须显示 x86_64；若是 aarch64/arm64，不要使用此包。校验失败也不要继续。

这是 Ubuntu 直连部署方式。如果服务器此前使用不同服务名或安装目录，还必须传回原 SERVICE_NAME / --install-dir 等参数；不要擅自迁移到另一实例。安装期间会短暂中断正在处理的请求。

默认安装目录仍是 /opt/sub2api，程序迁移到 /opt/sub2api/bin/sub2api；数据库仍是 /opt/sub2api/data/sub2api.db。已有 config.yaml 保留，不要使用 --force-config 或 --purge。

## 密码注意事项

**升级不会解决已经忘记的管理员密码，也不会把密码恢复为 123456。** 请使用原管理员邮箱和密码，或已通过密码重置操作设置的新密码。只有空数据库首次初始化才生成默认账号 123456@admin.com / 123456，首次登录必须立即改密。

如果仍提示密码错误，不要靠重复升级、删除数据库或覆盖 config.yaml 来重置密码。

## Git 发布

本包程序内版本为 0.1.139，对应 Git 标签必须为 v0.1.139。先把本包中的成品文件更新到你的成品仓库，提交并 push 后，再在该提交上创建并推送此标签。这里不含源码、.git 或任何发布令牌。

初次接入需要包含 install-ubuntu.sh 和 git-update.sh；以后修改 helper 或 systemd 配置时，也要管理员显式重新运行安装器。平常更新只替换 sub2api 二进制。

服务器必须能访问 GitHub；安装器在缺失时安装 Git、util-linux。完成首次部署后，后台“在线更新”可读取稳定标签，确认安装后再点“立即重启”。后台重启继续使用 systemd 保存的 9000 端口；重新运行安装器仍须明确带 --port 9000。

不要重复创建或移动已有版本标签。这里只是打包，没有替你提交、push、创建 tag 或操作线上服务。

## 回滚

仅保留上次在线更新前的程序 bin/sub2api.backup。回滚不还原数据库、配置或迁移，旧版必须与数据库兼容。程序无法启动时需要 SSH 手动恢复，网页回滚不可用。

本包已完成前端构建、相关自动测试、Git 脚本集成测试、Linux amd64 交叉编译及包内容校验。当前打包机器为 Windows，尚未在真实 Linux/systemd 主机上完成启动与升级重启演练。Git 脚本测试中的 Linux/执行探测使用了模拟。

详细 Git 更新说明见 ONLINE_UPDATE.md；构建来源见 BUILD_INFO.txt。
