{
  description = "Solona binaries and tools";

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
        flake-utils.follows = "flake-utils";
      };
    };

    solana-sbf-sdk = {
      flake = false;
      url = "https://github.com/solana-labs/solana/releases/download/v1.18.8/sbf-sdk.tar.bz2";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    crane,
    rust-overlay,
    flake-utils,
    solana-sbf-sdk,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [(import rust-overlay)];
      };
      rustOverlay =
        pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

      inherit (pkgs) lib;
      craneLib = (crane.mkLib pkgs).overrideToolchain rustOverlay;

      # Common arguments can be set here to avoid repeating them later
      commonArgs = {
        pname = "solana-cli";
        version = "1.18.8";
        strictDeps = true;
        OPENSSL_NO_VENDOR = "1";
      };

      solana-bins = craneLib.mkCargoDerivation (commonArgs
        // {
          cargoArtifacts = null;
          src = pkgs.fetchFromGitHub {
            owner = "solana-labs";
            repo = "solana";
            rev = "v${commonArgs.version}";
            sha256 = "sha256-v24AZXYjuKqpgR7pO03nQpySqpVOfevwka8tU+IjZQM=";
            fetchSubmodules = true;
          };
          doCheck = false;

          buildInputs = with pkgs; [
            openssl
            zlib
            libclang.lib
            hidapi
            udev
          ];

          nativeBuildInputs = with pkgs; [
            pkg-config
            protobuf
            rustfmt
            rustPlatform.bindgenHook
            perl
          ];
          LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
          BINDGEN_EXTRA_CLANG_ARGS = "-isystem ${pkgs.llvmPackages.libclang.lib}/lib/clang/${lib.getVersion pkgs.clang}/include";

          buildPhaseCargoCommand = "cargo build --release";
          doInstallCargoArtifacts = false;
          installPhase = ''
            mkdir -p $out
            ls -l target
            find target/release -maxdepth 1 -executable -type f -exec cp {} $out/ \;
            mkdir -p $out/sdk/sbf
            cp -r ${solana-sbf-sdk}/* $out/sdk/sbf
          '';
        });
    in {
      ######################################################
      ###                 Build packages                 ###
      ######################################################
      bin = solana-bins;
      packages = {
        default = solana-bins;
      };

      apps.default = flake-utils.lib.mkApp {drv = solana-bins;};
    });
}
