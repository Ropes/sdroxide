{
  description = "sdroxide Rust Development Environment";

  # Flake inputs
  inputs = {
    # Latest stable Nixpkgs
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
    # A helper library for Rust + Nix
    #rust-overlay.url = "https://flakehub.com/f/oxalica/rust-overlay/*";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  # Flake outputs
  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
    }:

    let
      overlays = [
        (import rust-overlay)
        (final: prev: {
          rustToolchain = prev.rust-bin.stable."1.96.0".default.override {
            extensions = [ "rust-src" "rust-analyzer" ];
          };
        })
      ];

      # Systems supported
      allSystems = [
        "x86_64-linux" # 64-bit Intel/AMD Linux
        "aarch64-linux" # 64-bit ARM Linux
        "aarch64-darwin" # 64-bit ARM macOS
      ];

      # Helper to provide system-specific attributes
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs allSystems (
          system:
          f {
            pkgs = import nixpkgs { inherit overlays system; };
          }
        );
    in
    {
      # Development environment output
      devShells = forAllSystems (
        { pkgs }:
        {
          shellHook = ''
            if [ -d .git ]; then
              echo "Initializing missing Git submodules..."
              git submodule update --init --recursive
            fi
          '';
          default = pkgs.mkShell {
            # The Nix packages provided in the environment
            nativeBuildInputs = with pkgs; [
              pkg-config
              cmake
              gcc
              gnumake
              autoconf
              automake
              libtool
            ];
            buildInputs = with pkgs; [
              libopus
              llvmPackages.libclang
              soapysdr-with-plugins
            ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ alsa-lib ];
            # Required by many build scripts (e.g., Rust's bindgen) to find libclang.so
            LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";

            # Tell bindgen where Nix's glibc and libclang built-in headers (stddef.h) live
            BINDGEN_EXTRA_CLANG_ARGS =
              (builtins.map (a: ''-I"${a}/include"'') [
                pkgs.glibc.dev
              ])
              ++ [
                ''-isystem "${pkgs.llvmPackages.libclang.lib}/lib/clang/${pkgs.lib.versions.major pkgs.llvmPackages.libclang.version}/include"''
              ];

            packages = with pkgs; [
                # The package provided by our custom overlay. Includes cargo, Clippy, cargo-fmt,
                # rustdoc, rustfmt, and other tools.
                rustToolchain
              ]
              ++ pkgs.lib.optionals pkgs.stdenv.isDarwin (with pkgs; [ libiconv ]);
              # Required for some crates (e.g., bindgen, openssl-sys) and rust-analyzer
              RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
          };
        }
      );
    };
}
