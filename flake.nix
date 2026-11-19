{
  description = "Example Rust development environment for Zero to Nix";

  # Flake inputs
  inputs = {
    # Latest stable Nixpkgs
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
    # A helper library for Rust + Nix
    rust-overlay.url = "https://flakehub.com/f/oxalica/rust-overlay/*";

  };

  # Flake outputs
  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
    }:
    let
      # Overlays enable you to customize the Nixpkgs attribute set
      overlays = [
        # Makes a `rust-bin` attribute available in Nixpkgs
        (import rust-overlay)
        # Provides a `rustToolchain` attribute for Nixpkgs that we can use to
        # create a Rust environment
        (final: prev: {
          rustToolchain = prev.rust-bin.stable.latest.default;
        })
      ];

      # Systems supported
      allSystems = [
        "x86_64-linux" # 64-bit Intel/AMD Linux
        # "aarch64-linux" # 64-bit ARM Linux
        # "aarch64-darwin" # 64-bit ARM macOS
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
            if [ -d .git ] && [ ! -f vendor/xng/Cargo.toml ]; then
              echo "Initializing missing Git submodules..."
              git submodule update --init --recursive
            fi
          '';
          default = pkgs.mkShell {
            # The Nix packages provided in the environment
            nativeBuildInputs = with pkgs; [
              pkg-config
              cmake
              autoconf
              automake
              libtool
            ];
            buildInputs = with pkgs; [
              alsa-lib
              libopus
              llvmPackages.libclang
            ];
            # Required by many build scripts (e.g., Rust's bindgen) to find libclang.so
            #LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";`

            packages =
              (with pkgs; [
                # The package provided by our custom overlay. Includes cargo, Clippy, cargo-fmt,
                # rustdoc, rustfmt, and other tools.
                rustToolchain
              ])
              ++ pkgs.lib.optionals pkgs.stdenv.isDarwin (with pkgs; [ libiconv ]);
          };
        }
      );
    };
}
