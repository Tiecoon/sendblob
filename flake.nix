{
  description = "Minimal sendblob container and frontend build tools";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/1c89083e451e891152365b799595cf7790a43325";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          # dist is deliberately supplied at invocation time: it is generated,
          # gitignored output and therefore absent from the flake source.
          default = pkgs.writeShellApplication {
            name = "sendblob-build-image";
            runtimeInputs = [ pkgs.nix ];
            text = ''
              if [[ ! -f dist/index.html ]]; then
                echo "Run npm run build:release from the repository root first." >&2
                exit 1
              fi
              export SENDBLOB_DIST="$PWD/dist"
              nix-build ${./default.nix} \
                --arg pkgs 'import ${nixpkgs} {}' \
                --arg webRoot 'builtins.path { path = builtins.getEnv "SENDBLOB_DIST"; name = "sendblob-dist"; }' \
                --out-link /tmp/sendblob-image "$@"
            '';
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nodejs_24
              pkgs.binaryen
              pkgs.wasm-bindgen-cli
              pkgs.cargo
              pkgs.rustc
              pkgs.lld
              pkgs.llvmPackages.clang-unwrapped
              pkgs.llvmPackages.llvm
            ];
            CC_wasm32_unknown_unknown = "clang";
            AR_wasm32_unknown_unknown = "llvm-ar";
          };
        }
      );
    };
}
