{
  description = "Helium browser, repackaged from upstream's signed release (personal use)";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      # Only reached with withWidevine = true.
      config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "widevine-cdm";
    };
  in {
    packages.${system} = {
      helium = pkgs.callPackage ./package.nix {};
      default = self.packages.${system}.helium;

      update = pkgs.writeShellApplication {
        name = "helium-update";
        runtimeInputs = with pkgs; [curl jq gnupg nix coreutils];
        text = builtins.readFile ./update.sh;
      };
    };

    overlays.default = final: _prev: {
      helium = final.callPackage ./package.nix {};
    };
  };
}
