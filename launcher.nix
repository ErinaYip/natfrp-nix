{
  writeShellApplication,
  coreutils,
  natfrp-runtime,
}:

# Mirrors the Docker-mode interaction flow from upstream launcher.sh:
# https://doc.natfrp.com/launcher.sh
# Keep upstream attribution/copyright notices if launcher.sh is vendored or updated.
writeShellApplication {
  name = "natfrp-launcher";

  runtimeInputs = [
    coreutils
    natfrp-runtime
  ];

  text = ''
    set -euo pipefail

    default_config_base() {
      if [ -n "''${NATFRP_CONFIG_BASE:-}" ]; then
        printf '%s\n' "$NATFRP_CONFIG_BASE"
      elif [ -n "''${XDG_STATE_HOME:-}" ]; then
        printf '%s\n' "$XDG_STATE_HOME/natfrp"
      elif [ -n "''${HOME:-}" ]; then
        printf '%s\n' "$HOME/.local/state/natfrp"
      else
        printf '%s\n' "$PWD/.natfrp-run"
      fi
    }

    CONFIG_BASE="$(default_config_base)"

    log_i() { printf '\033[32m[+] %s\033[0m\n' "$1"; }
    log_w() { printf '\033[33m[!] %s\033[0m\n' "$1"; }
    log_e() { printf '\033[31m[-] %s\033[0m\n' "$1"; }

    usage() {
      cat <<EOF
Usage: natfrp-launcher [run|recreate|uninstall|help]

Commands:
  run        Start with existing config, or ask for credentials on first run.
  recreate   Ask for credentials again and update config before starting.
  uninstall  Remove the persistent config directory after confirmation.
  help       Show this help.

Environment:
  NATFRP_CONFIG_BASE  Persistent config directory.
                     Default: XDG_STATE_HOME/natfrp or ~/.local/state/natfrp
  TZ                  Time zone passed to runtime, default: Asia/Shanghai
EOF
    }

    ensure_config_dir() {
      install -d -m 0700 "$CONFIG_BASE"
    }

    ask_for_creds() {
      while true; do
        read -r -p "请输入 SakuraFrp 的访问密钥 (可在 https://www.natfrp.com/user/ 获取): " api_key
        printf '\n'
        if [ "''${#api_key}" -ge 16 ]; then
          break
        fi
        log_e "访问密钥错误, 请到 https://www.natfrp.com/user/ 获取"
      done

      while true; do
        while true; do
          read -r -p "请输入远程管理密码 (至少八个字符): " remote_pass
          printf '\n'
          if [ "''${#remote_pass}" -ge 8 ]; then
            break
          fi
          log_e "远程管理密码至少需要 8 字符"
        done

        read -r -p "请再次输入远程管理密码: " remote_pass_confirm
        printf '\n'
        if [ "$remote_pass" = "$remote_pass_confirm" ]; then
          break
        fi
        log_e "两次输入的远程管理密码不一致, 请确认知晓自己正在输入的内容"
      done
    }

    run_existing() {
      log_i "使用已有配置启动: $CONFIG_BASE/config.json"
      exec env NATFRP_SERVICE_WD="$CONFIG_BASE" TZ="''${TZ:-Asia/Shanghai}" natfrp
    }

    run_with_creds() {
      exec env \
        NATFRP_SERVICE_WD="$CONFIG_BASE" \
        NATFRP_TOKEN="$api_key" \
        NATFRP_REMOTE="$remote_pass" \
        TZ="''${TZ:-Asia/Shanghai}" \
        natfrp
    }

    uninstall_config() {
      if [ ! -d "$CONFIG_BASE" ]; then
        log_i "配置目录不存在: $CONFIG_BASE"
        exit 0
      fi

      read -r -p " - 确认删除 SakuraFrp 启动器配置目录 $CONFIG_BASE 吗? [y/N] " choice
      case "$choice" in
        y|Y)
          rm -rf "$CONFIG_BASE"
          log_i "已删除配置目录: $CONFIG_BASE"
          ;;
        *)
          log_i "未删除配置目录"
          ;;
      esac
    }

    command="''${1:-run}"
    case "$command" in
      help|-h|--help)
        usage
        ;;
      run)
        ensure_config_dir
        if [ -f "$CONFIG_BASE/config.json" ]; then
          run_existing
        fi
        log_w "未发现已有配置，将按 Docker 模式初始化启动器"
        ask_for_creds
        run_with_creds
        ;;
      recreate|reconfigure)
        ensure_config_dir
        log_w "将重新写入访问密钥和远程管理配置"
        ask_for_creds
        run_with_creds
        ;;
      uninstall)
        uninstall_config
        ;;
      *)
        usage
        exit 64
        ;;
    esac
  '';
}
