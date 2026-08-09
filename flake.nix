{
  description = "SakuraFrp Launcher packaged as a Nix flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      version = "3.1.8";

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "i686-linux"
        "armv7l-linux"
        "riscv64-linux"
      ];

      archFor = {
        x86_64-linux = "amd64";
        aarch64-linux = "arm64";
        i686-linux = "386";
        armv7l-linux = "armv7";
        riscv64-linux = "riscv64";
      };

      hashes = {
        x86_64-linux = "sha256-AHFAUqiPHll2osQ3nHA8mF7uWULPKG2rhrtGaLJye3g=";
        aarch64-linux = "sha256-NE+8A6izSnRvGWNerqGOnGlnOzHxMoLeLYw/EfT9nGs=";
        i686-linux = "sha256-nv2yUg42n/zUy75WPD1cMJggINRKDZj8DKnoCXtnQ4M=";
        armv7l-linux = "sha256-ANa//H2ib9yseKMCwMLLdeK0gD1BQ3YcayPq9C8D9S8=";
        riscv64-linux = "sha256-FezXskx5xclwjM5MVY6Guvd3bKshCMI0SetCs+fcmXE=";
      };

      forAllSystems = f: lib.genAttrs systems (system: f system);

      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg: lib.getName pkg == "natfrp-launcher";
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          natfrp-launcher = pkgs.callPackage ./package.nix {
            inherit version;
            arch = archFor.${system};
            hash = hashes.${system};
          };
          natfrp-runtime = pkgs.callPackage ./runtime.nix {
            inherit natfrp-launcher;
          };
          natfrp-interactive = pkgs.callPackage ./launcher.nix {
            inherit natfrp-runtime;
          };
        in
        {
          inherit natfrp-launcher natfrp-runtime natfrp-interactive;
          default = natfrp-interactive;
        }
      );

      apps = forAllSystems (system: {
        launcher = {
          type = "app";
          program = "${self.packages.${system}.natfrp-interactive}/bin/natfrp-launcher";
          meta.description = "Run the interactive SakuraFrp Launcher setup";
        };
        runtime = {
          type = "app";
          program = "${self.packages.${system}.natfrp-runtime}/bin/natfrp";
          meta.description = "Run SakuraFrp Launcher with the Docker-compatible Nix runtime";
        };
        natfrp-service = {
          type = "app";
          program = "${self.packages.${system}.natfrp-launcher}/bin/natfrp-service";
          meta.description = "Run SakuraFrp Launcher service";
        };
        default = self.apps.${system}.launcher;
      });
    };
}
