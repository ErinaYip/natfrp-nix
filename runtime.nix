{
  writeShellApplication,
  coreutils,
  gnused,
  iproute2,
  jq,
  natfrp-launcher,
}:

# Mirrors /run.sh from the official natfrp.com/launcher Docker image.
# Keep upstream attribution/copyright notices if the Docker entrypoint is vendored or updated.
writeShellApplication {
  name = "natfrp";

  runtimeInputs = [
    coreutils
    gnused
    iproute2
    jq
    natfrp-launcher
  ];

  text = ''
    set -euo pipefail

    config_path="''${NATFRP_SERVICE_WD:-/run}"
    config_file="$config_path/config.json"

    export NATFRP_SERVICE_WD="$config_path"
    export NATFRP_SERVICE_DOCKER="''${NATFRP_SERVICE_DOCKER:-1}"
    export NATFRP_UPDATE_OVERRIDE="''${NATFRP_UPDATE_OVERRIDE:-launcher-docker}"
    export TZ="''${TZ:-Asia/Shanghai}"

    printf '\nSakuraFrp Launcher\n'
    printf 'Nix runtime compatible with the official Docker entrypoint\n\n'

    if [ ! -d "$config_path" ]; then
      printf '============= Critical Error =============\n'
      printf '配置文件目录不存在，请先创建目录或设置 NATFRP_SERVICE_WD\n'
      exit 1
    fi

    if [ ! -w "$config_path" ]; then
      printf '============= Critical Error =============\n'
      printf '配置文件目录不可写，请检查权限或设置 NATFRP_SERVICE_WD\n'
      exit 1
    fi

    if [ ! -f "$config_file" ]; then
      printf '[*] 正在生成配置文件...\n'

      natfrp-service --daemon > /dev/null &
      spid=$!

      for delay in 0.5 0.5 1 2 2; do
        if [ -f "$config_file" ]; then
          break
        fi
        sleep "$delay"
      done

      printf '[*] 等待进程退出...\n'
      kill "$spid" 2> /dev/null || true
      counter=5
      while kill -0 "$spid" 2> /dev/null; do
        if [ "$counter" -eq 0 ]; then
          printf '[!] 进程退出超时，正在强制结束...\n'
          kill -9 "$spid" 2> /dev/null || true
          wait "$spid" 2> /dev/null || true
          break
        fi
        counter=$((counter - 1))
        sleep 1
      done
      wait "$spid" 2> /dev/null || true
    fi

    if [ ! -f "$config_file" ]; then
      printf '============= Critical Error =============\n'
      printf 'Cannot create config file, please contact us\n'
      exit 1
    fi

    if [ "''${NATFRP_TOKEN:-}" != "" ] && [ "''${NATFRP_REMOTE:-}" != "" ]; then
      printf '[*] 远程管理模式已配置，正在修改配置文件...\n'
      if [ "''${#NATFRP_REMOTE}" -lt 8 ]; then
        printf '============= Critical Error =============\n'
        printf '远程管理密钥长度过短, 请至少输入 8 位字符\n'
        exit 1
      fi

      remote_key="$(natfrp-service remote-kdf "$NATFRP_REMOTE")"
      tmp_file="$config_file.tmp"
      jq --arg token "$NATFRP_TOKEN" \
        --arg remote_key "$remote_key" \
        '.remote_management = true | .remote_management_key = $remote_key | .token = $token' \
        "$config_file" > "$tmp_file"
      mv "$tmp_file" "$config_file"
    fi

    unset NATFRP_TOKEN NATFRP_REMOTE remote_key tmp_file || true

    printf '[+] 启动器配置初始化成功\n\n'
    printf '============= 启动器连接信息 =============\n'

    if [ "$(jq -r '.remote_management' "$config_file")" = "true" ]; then
      printf '> 远程管理模式已开启, 请到管理面板使用远程管理连接\n'
    fi

    webui_port="$(jq -r '.webui_port' "$config_file")"
    webui_pass="$(jq -r '.webui_pass' "$config_file")"

    printf 'WebUI 端口: %s\n' "$webui_port"
    printf 'WebUI 密码: %s\n\n' "$webui_pass"

    default_ip="$(ip route get 223.5.5.5 2> /dev/null | sed -n 's/^.*src \([0-9.]*\) .*$/\1/p')"
    if [ "''${default_ip:0:4}" = "172." ]; then
      printf 'Docker 网络模式不是 host, 请确认您已正确映射容器端口 %s, 推荐使用 host 网络以简化配置流程\n' "$webui_port"
      printf '使用 https://<访问本机用的IP>:%s 进行连接\n' "$webui_port"
    else
      if [ -z "$default_ip" ]; then
        default_ip="<访问本机用的IP>"
      fi
      printf '使用 https://%s:%s 进行连接\n' "$default_ip" "$webui_port"
      printf '如果您使用非内网访问或使用和上面 IP 不通的网络, 请使用 https://<访问本机用的IP>:%s 进行连接\n' "$webui_port"
    fi

    printf '============= 启动器连接信息 =============\n\n'

    exec natfrp-service --daemon
  '';
}
