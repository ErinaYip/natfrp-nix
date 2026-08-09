{ self }:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.natfrp;
  settingsFormat = pkgs.formats.json { };
  settingsFile = settingsFormat.generate "natfrp-settings.json" cfg.settings;
  system = pkgs.stdenv.hostPlatform.system;
  defaultPackage =
    self.packages.${system}.default
      or (throw "natfrp-nix does not support ${system}");
in
{
  options.services.natfrp = {
    enable = lib.mkEnableOption "SakuraFrp Launcher";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      defaultText = lib.literalExpression "inputs.natfrp-nix.packages.${pkgs.stdenv.hostPlatform.system}.default";
      description = "SakuraFrp Launcher package to run.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "natfrp";
      description = "User that runs natfrp-service.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "natfrp";
      description = "Group that runs natfrp-service.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/natfrp";
      description = "Writable directory used as NATFRP_SERVICE_WD.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/etc/natfrp/natfrp.env";
      description = ''
        Optional root-only EnvironmentFile. Set NATFRP_TOKEN and NATFRP_REMOTE
        here to initialize remote management without putting secrets in the Nix store.
      '';
    };

    settings = lib.mkOption {
      type = settingsFormat.type;
      default = {
        log_stdout = true;
      };
      description = ''
        Extra config.json settings merged before secrets from environmentFile.
        Do not put access tokens or remote passwords here unless you accept them
        being stored in the Nix store.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.natfrp.dataDir must be an absolute path.";
      }
    ];

    users.groups.${cfg.group} = { };
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
      description = "SakuraFrp Launcher service user";
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.natfrp = {
      description = "SakuraFrp Launcher";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment.NATFRP_SERVICE_WD = cfg.dataDir;

      preStart = ''
        set -eu

        umask 0077
        config_dir="$NATFRP_SERVICE_WD"
        config_file="$config_dir/config.json"
        tmp_file="$config_file.tmp"

        install -d -m 0750 -o ${cfg.user} -g ${cfg.group} "$config_dir"

        if [ ! -s "$config_file" ]; then
          printf '{}\n' > "$config_file"
        fi

        ${pkgs.jq}/bin/jq -s '.[0] + .[1]' "$config_file" "${settingsFile}" > "$tmp_file"
        mv "$tmp_file" "$config_file"

        if [ -n "''${NATFRP_TOKEN:-}" ]; then
          ${pkgs.jq}/bin/jq --arg token "$NATFRP_TOKEN" '.token = $token' "$config_file" > "$tmp_file"
          mv "$tmp_file" "$config_file"
        fi

        if [ -n "''${NATFRP_REMOTE:-}" ]; then
          remote_key="$(${lib.getExe cfg.package} remote-kdf "$NATFRP_REMOTE")"
          ${pkgs.jq}/bin/jq --arg remote_key "$remote_key" '.remote_management = true | .remote_management_key = $remote_key' "$config_file" > "$tmp_file"
          mv "$tmp_file" "$config_file"
        fi

        chown ${cfg.user}:${cfg.group} "$config_file"
        chmod 0600 "$config_file"
      '';

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        PermissionsStartOnly = true;
        Type = "simple";
        TimeoutStopSec = 20;
        Restart = "always";
        RestartSec = "5s";
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${lib.getExe cfg.package} --daemon --systemd";
      }
      // lib.optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };
    };
  };
}
