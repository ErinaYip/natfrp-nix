# natfrp-nix

SakuraFrp 启动器的 Nix flake 运行环境。它不会创建 Docker 容器，也不会创建 systemd unit。实现方式是用 Nix 固定打包同一套 `frpc`、`natfrp-service`，并复刻官方 Docker 镜像入口脚本 `/run.sh` 的运行逻辑。

默认 app 额外结合了 `launcher.sh` 的 Docker 模式交互流程：首次运行询问 SakuraFrp 访问密钥和远程管理密码；之后再次运行会复用已有配置。

## 首次运行

默认配置会保存到当前用户可写的状态目录：`$XDG_STATE_HOME/natfrp` 或 `~/.local/state/natfrp`。

```sh
nix run .#
```

如果要显式指定目录：

```sh
mkdir -p ./.natfrp-run
NATFRP_CONFIG_BASE="$PWD/.natfrp-run" nix run .#
```

## 再次运行

如果 `config.json` 已存在，继续运行同一条命令即可。launcher 会跳过密钥输入，直接使用已有配置启动：

```sh
nix run .#
```

用户目录配置对应命令：

```sh
NATFRP_CONFIG_BASE="$PWD/.natfrp-run" nix run .#
```

如果要更换访问密钥或远程管理密码：

```sh
nix run .# -- recreate
```

如果要删除持久配置目录：

```sh
nix run .# -- uninstall
```

## Docker-compatible runtime

底层 runtime 也可以用 Docker 风格环境变量直接调用：

```sh
mkdir -p ./.natfrp-run
env \
  NATFRP_SERVICE_WD="$PWD/.natfrp-run" \
  NATFRP_TOKEN="你的_SakuraFrp_访问密钥" \
  NATFRP_REMOTE="你的远程管理密码" \
  TZ=Asia/Shanghai \
  nix run .#runtime
```

它对应 `natfrp.com/launcher` 镜像配置：

- 镜像命令：`/run.sh`
- 镜像工作目录：`/run`
- 默认环境变量：`NATFRP_TOKEN=`、`NATFRP_REMOTE=`、`TZ=Asia/Shanghai`

runtime 复刻了 `/run.sh` 的主要行为：

- 首次运行时短暂启动 `natfrp-service --daemon` 生成 `config.json`
- 用 `NATFRP_TOKEN` 和 `NATFRP_REMOTE` 修改配置
- 用 `natfrp-service remote-kdf` 转换远程管理密码
- 输出 WebUI 连接信息
- 最后以前台方式运行 `natfrp-service --daemon`

## 原始二进制

原始上游二进制仍然单独暴露，方便检查版本：

```sh
nix build .#natfrp-launcher
./result/bin/natfrp-service -v
./result/bin/frpc -v
```

## 上游说明

`launcher.nix` 参考上游 `launcher.sh` 的 Docker 模式交互流程，来源是 `https://doc.natfrp.com/launcher.sh`；`runtime.nix` 参考官方 `natfrp.com/launcher` Docker 镜像中的 `/run.sh`。上游版权和署名属于 SakuraFrp/Natfrp 项目；如果之后把这些脚本原文 vendoring 到仓库，或同步上游脚本，请保留原始版权和署名信息。
