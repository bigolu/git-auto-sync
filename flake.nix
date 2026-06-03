{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    blueprint = { url = "github:numtide/blueprint"; inputs.nixpkgs.follows = "nixpkgs"; };
    devshell = { url = "github:numtide/devshell"; inputs.nixpkgs.follows = "nixpkgs"; };
    flake-compat.url = "https://git.lix.systems/lix-project/flake-compat/archive/main.tar.gz";
    devshell-modules.url = "github:bigolu/devshell-modules";
  };

  outputs = inputs: 
    let
      bp = inputs.blueprint { inherit inputs; prefix = "nix/outputs"; };
    in
    bp // {
      overlays.default = final: _prev:
        { git-auto-sync = (bp.mkPackagesFor final).default; };
    };
}
