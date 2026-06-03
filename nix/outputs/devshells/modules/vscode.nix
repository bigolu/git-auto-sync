{ pkgs, ... }:
{
  imports = [
    # For extension "maximsmol.vscode-lsp-generic"
    {
      devshell.packages = with pkgs; [
        efm-langserver

        # efm-langserver launches commands with`sh`
        dash
        # These are used in the efm-langserver config
        markdownlint-cli2
        statix
      ];
    }
  ];

  devshell.packages = with pkgs; [
    # For extension "jnoortheen.nix-ide"
    nixd
    # For extension "mads-hartmann.bash-ide-vscode"
    shellcheck
  ];
}
