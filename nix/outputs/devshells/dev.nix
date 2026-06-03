{ perSystem, inputs, ... }:
perSystem.devshell.mkShell (
  { extraModulesPath, ... }:
  {
    imports = [
      "${extraModulesPath}/locale.nix"
      perSystem.self.default.devshellModule
      ./modules/vscode.nix
    ]
    ++ (with inputs.devshell-modules.devshellModules; [
      minimal
      autocomplete
      state
      gcRoot
    ]);

    gcRoot.roots.flake.inputs = inputs;

    devshell.startup.repl-overlay.text = ''
      export NIX_CONFIG="
        ''${NIX_CONFIG:-}
        extra-repl-overlays = $PRJ_ROOT/nix/repl-overlay.nix
      "
    '';
  }
)
