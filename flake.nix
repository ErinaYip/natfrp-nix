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
        x86_64-linux = "sha256-xwWd9835sGrwuRgrvXUX2Xj0dNwLRKhuAffvSpJwQio=";
        aarch64-linux = "sha256-Mu/zM/qLZjPCFudNUwbHMIM+7O95Ta8StUm4WIR48kM=";
        i686-linux = "sha256-zI5D5aNlKJMdl9urnBI93bl9oHDMldC3N77r12tTUqg=";
        armv7l-linux = "sha256-cVBamfZFJDRr2z5Ro/03Bj1QkbNcTnpdRMMsjgH8tpw=";
        riscv64-linux = "sha256-zx+LF8OQQU+rHm73c1W8qvJP4eaXhGgxP4pbkU35+AQ=";
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
