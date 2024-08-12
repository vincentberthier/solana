{
  description = "Solana binaries and tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    crane,
    rust-overlay,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      solana-version = "1.18.22";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [(import rust-overlay)];
      };
      rustOverlay = pkgs.rust-bin.stable.latest.default;

      inherit (pkgs) lib;
      craneLib = (crane.mkLib pkgs).overrideToolchain rustOverlay;

      # Common arguments can be set here to avoid repeating them later
      commonArgs = {
        pname = "solana-cli";
        version = solana-version;
        strictDeps = true;
        OPENSSL_NO_VENDOR = "1";
      };

      solana-packages = [
        "agave-install"
        "agave-ledger-tool"
        "agave-validator"
        "agave-install-init"
        "agave-watchtower"
        "solana"
        "solana-bench-tps"
        "solana-faucet"
        "solana-gossip"
        "solana-keygen"
        "solana-log-analyzer"
        "solana-net-shaper"
        "solana-dos"
        "solana-stake-accounts"
        "solana-test-validator"
        "solana-tokens"
        "solana-genesis"
      ];
      cargoBuildFlags = lib.concatStrings (builtins.map (n: "--bin=${n} ") solana-packages);

      solana-bins = craneLib.mkCargoDerivation (commonArgs
        // {
          cargoArtifacts = null;
          src = pkgs.fetchFromGitHub {
            owner = "anza-xyz";
            repo = "agave";
            rev = "v${commonArgs.version}";
            sha256 = "sha256-rT3eR0A7D9l/qr+v55X4JMouayS/w8SaaxyhY8xOCAA=";
            # sha256 = lib.fakeHash;
            fetchSubmodules = true;
          };
          doCheck = false;

          buildInputs = with pkgs; [
            openssl
            zlib
            libclang.lib
            hidapi
            udev
            rocksdb
          ];

          nativeBuildInputs = with pkgs; [
            pkg-config
            protobuf
            rustfmt
            rustPlatform.bindgenHook
            perl
          ];
          ROCKSDB_LIB_DIR = "${pkgs.rocksdb}/lib";
          LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
          BINDGEN_EXTRA_CLANG_ARGS = "-isystem ${pkgs.llvmPackages.libclang.lib}/lib/clang/${lib.getVersion pkgs.clang}/include";

          buildPhaseCargoCommand = "cargo build --release ${cargoBuildFlags}";
          doInstallCargoArtifacts = false;
          installPhase = ''
            mkdir -p $out/bin/sdk/sbf
            find target/release -maxdepth 1 -executable -type f -exec cp -a {} $out/bin/ \;
          '';
        });
    in {
      ######################################################
      ###                 Build packages                 ###
      ######################################################
      packages = {
        default = solana-bins;
      };

      apps.default = flake-utils.lib.mkApp {drv = solana-bins;};
    });
}
