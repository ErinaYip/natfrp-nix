# natfrp-nix

Chinese version: [README.zh.md](README.zh.md)

Nix flake runtime for SakuraFrp Launcher. It does not create a Docker container
or a systemd unit. Instead, it packages the same `frpc` and `natfrp-service`
binaries and mirrors the official Docker image entrypoint (`/run.sh`) with Nix.

The default app adds an interactive launcher flow based on `launcher.sh` Docker
mode: first run asks for `NATFRP_TOKEN` and remote management password; later
runs reuse the existing config.

## First Run

By default, config is stored in a user-writable state directory:
`$XDG_STATE_HOME/natfrp` or `~/.local/state/natfrp`.

```sh
nix run .#
```

To use an explicit directory:

```sh
mkdir -p ./.natfrp-run
NATFRP_CONFIG_BASE="$PWD/.natfrp-run" nix run .#
```

## Run Again

If `config.json` already exists, run the same command again. The launcher will
skip credential prompts and start with the existing config:

```sh
nix run .#
```

For a user-local config:

```sh
NATFRP_CONFIG_BASE="$PWD/.natfrp-run" nix run .#
```

To change token or remote management password:

```sh
nix run .# -- recreate
```

To remove the persistent config directory:

```sh
nix run .# -- uninstall
```

## Docker-Compatible Runtime

The lower-level runtime can be called directly with Docker-style environment
variables:

```sh
mkdir -p ./.natfrp-run
env \
  NATFRP_SERVICE_WD="$PWD/.natfrp-run" \
  NATFRP_TOKEN="your_sakurafrp_access_token" \
  NATFRP_REMOTE="your_remote_management_password" \
  TZ=Asia/Shanghai \
  nix run .#runtime
```

This follows the image config for `natfrp.com/launcher`:

- image command: `/run.sh`
- image working directory: `/run`
- env defaults: `NATFRP_TOKEN=`, `NATFRP_REMOTE=`, `TZ=Asia/Shanghai`

The runtime behavior mirrors `/run.sh`:

- generate `config.json` by briefly starting `natfrp-service --daemon`
- apply `NATFRP_TOKEN` and `NATFRP_REMOTE` to the config
- convert the remote password with `natfrp-service remote-kdf`
- print WebUI connection information
- run `natfrp-service --daemon` in the foreground

## Raw Binaries

The raw upstream service binaries are exposed for inspection:

```sh
nix build .#natfrp-launcher
./result/bin/natfrp-service -v
./result/bin/frpc -v
```

## Updating Hashes

Upstream re-publishes the tarballs in place, so the pinned `hashes` in
`flake.nix` can go stale for an unchanged `version`. Refresh them with:

```sh
./update-hashes.sh        # keep the current version
./update-hashes.sh 3.1.9  # bump version and refresh hashes
```

If you prefer doing it by hand, the fetch is a plain fixed-output derivation;
capture the `got:` hash from the mismatch error and put it into `flake.nix`:

```sh
nix build .#natfrp-launcher
# error: hash mismatch ... got: sha256-...
```

## Upstream Notes

`launcher.nix` mirrors the Docker-mode interaction flow from upstream
`launcher.sh` at `https://doc.natfrp.com/launcher.sh`. `runtime.nix` mirrors
`/run.sh` from the official `natfrp.com/launcher` Docker image. Upstream
copyright and attribution belong to the SakuraFrp/Natfrp project; keep their
notices intact if vendoring or updating those scripts.
