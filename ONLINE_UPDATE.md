# Git 标签在线更新（成品仓库）

更新源固定为 `ker-ge/single-sub2api`。仓库只放已经编译好的文件，不需要公开源码、GitHub Actions、Release、压缩包或 checksums.txt。

## 你的发布流程

1. 本地编译新的 Linux 程序（包含前端），指定递增版本号，例如 `0.1.139`。
2. 把新程序复制到成品仓库根目录，文件名固定为 `sub2api`。
3. 提交并 `git push`，然后为这个提交创建并推送 `v0.1.139` 标签。也可以在 GitHub 为该提交创建标签，不需要创建 Release。
4. 管理后台点“在线更新”，检查标签，确认安装，完成后点“立即重启”。

必须让标签版本与程序内版本一致。Linux 本地构建示例（在源码仓库运行，输出目录先自行准备）：

```bash
pnpm --dir frontend install --frozen-lockfile
pnpm --dir frontend run build
cd backend
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -tags embed -trimpath \
  -ldflags="-s -w -X main.Version=0.1.139 -X main.BuildType=release" \
  -o /path/to/binary-repo/sub2api ./cmd/server
```

然后在成品仓库执行（版本仅为示例，须选未使用的新版本）：

```bash
git add sub2api
git commit -m "Update binary to 0.1.139"
git push origin main
git tag v0.1.139
git push origin v0.1.139
```

仅 push 不打标签，不会安装该提交。使用递增、不可复用的 `v主版本.次版本.修订号` 标签；不把预发布标签作为稳定更新，也不移动已发布标签。最新指语义版本最大的稳定标签，而不是最近创建的旧版本标签。旧程序内部版本若与新标签不同，更新会明确拒绝，不会反复误报更新。

## 首次接入（已有服务器也需要做一次）

把以下文件放入成品仓库根目录并上传；不需要添加源码：

```text
sub2api              新编译的程序
install-ubuntu.sh    使用本源码目录 deploy/linux/install-ubuntu.sh
git-update.sh        使用本源码目录 deploy/linux/git-update.sh
README.md
```

服务器上可以继续用普通 Git 工作目录管理成品：

```bash
git clone https://github.com/ker-ge/single-sub2api.git
cd single-sub2api
sudo bash install-ubuntu.sh --package-dir "$PWD"
```

已有 clone 则先 `git pull --ff-only`，再运行安装脚本。自定义安装目录、服务名、端口须沿用原参数，不要使用 `--force-config`。安装前另外备份 SQLite、配置和密钥。新版安装器将程序放在 `/opt/sub2api/bin/sub2api`，兼容备份旧的 `/opt/sub2api/sub2api`，数据库路径不变。

Ubuntu 安装器在缺少时安装 Git 和 util-linux；不安装 Go、Node 或 Docker。在线更新要求 Linux + systemd，启用 `SUB2API_ONLINE_UPDATE=true`、`SUB2API_UPDATE_SCRIPT=/opt/sub2api/deploy/linux/git-update.sh`、`Restart=always`，并允许 systemd 写入 `bin` 目录。Windows/macOS 可以安装 Git 后检查标签，但不能网页替换程序和重启。

## 服务器实际执行什么

- 检查：`git ls-remote --tags` 查询远端稳定标签，按版本号选最高版本；支持普通标签和附注标签。
- 拉取：在 `bin/.update-git` 独立缓存中浅拉取选中提交，并重新确认标签仍指向它。**不是直接 pull main**，避免版本号与实际安装文件错位；不会修改你手动 clone 的仓库。
- 执行：运行首次安装时部署好的本地 `git-update.sh`。不会运行下载仓库里的任意 root 安装脚本，不授予程序 sudo 权限。
- 验证：提交必须匹配，仓库根目录 `sub2api` 必须是普通 Git 文件、Linux ELF、匹配 CPU 架构，并且 `sub2api -version` 必须对应标签。
- 替换：在相同文件系统暂存，保留 `bin/sub2api.backup` 后原子替换，等待后台“立即重启”。数据库和配置不由更新脚本覆盖。

Git 本身验证对象完整性；这不是独立发布签名。只有可信维护者应能写入仓库和标签。当前不支持 Git LFS 指针；一个根目录程序只能对应一种 CPU 架构。配置 `update.proxy_url` 时会传给 Git 的 HTTPS 代理；代理失败不主动回退直连。进程环境的 Git 代理配置也需可用。

## 重启、回滚和手动处理

当前是“push + tag 发布，后台确认更新”，不是定时无人值守自动升级。更新期间旧进程继续运行；确认重启会短暂中断请求，页面等待健康检查后刷新。

程序更新或回滚后，重启之前不允许再次替换。只保留一份上一版程序。回滚不恢复数据库、配置或迁移；升级前务必备份并确认旧版本数据兼容性。程序已无法启动时，网页也不可用，需要 SSH 手动恢复程序及必要的数据备份。

如果选择 SSH 全手动更新，也可以在成品工作目录执行 `git fetch --tags`，`git checkout --detach v0.1.139`，然后用既有安装脚本执行 `sudo bash install-ubuntu.sh upgrade --package-dir "$PWD"`；带回原安装参数并提前备份。

```bash
sudo systemctl status sub2api
sudo journalctl -u sub2api -n 100 --no-pager
sudo systemctl cat sub2api
```

本次实现不会替你提交、推送或创建远端标签，也不会操作线上服务器。后续更新 helper 或 systemd 配置时，仍需管理员显式重新运行安装器。
