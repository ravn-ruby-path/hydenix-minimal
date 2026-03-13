{ inputs }:

final: prev:
let
  # Helper function to import a package
  callPackage = prev.lib.callPackageWith (prev // packages // inputs);

  # Fresh unstable pkgs set with allowUnfree — use as pkgs.unstable.<name>
  # This always gives the latest version regardless of hydenix's pinned nixpkgs.
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit (prev) system;
    config.allowUnfree = true;
  };

  # Define all packages
  packages = {
    # Hyde core packages
    hyde-gallery = callPackage ./hyde-gallery.nix { };
    # Additional packages
    pokego = callPackage ./pokego.nix { };
    python-pyamdgpuinfo = callPackage ./python-pyamdgpuinfo.nix { };
    Tela-circle-dracula = callPackage ./Tela-circle-dracula.nix { };
    Bibata-Modern-Ice = callPackage ./Bibata-Modern-Ice.nix { };
    hyde = callPackage ./hyde.nix { inherit inputs; };
    hydenix-themes = callPackage ./themes/default.nix { };
    hyq = inputs.hyq.packages.${prev.stdenv.hostPlatform.system}.default;
    hydectl = inputs.hydectl.packages.${prev.stdenv.hostPlatform.system}.default;
    hyde-ipc = inputs.hyde-ipc.packages.${prev.stdenv.hostPlatform.system}.default;
    hyde-config = inputs.hyde-config.packages.${prev.stdenv.hostPlatform.system}.default;

    # Expose unstable nixpkgs — use as pkgs.unstable.<package-name>
    # Example: pkgs.unstable.antigravity-fhs
    unstable = unstablePkgs;
  };
in
packages

