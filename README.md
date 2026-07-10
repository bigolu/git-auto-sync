# git-auto-sync

A CLI for automatically syncing your environment with the code when you pull/checkout new changes.

## Installation

Supports Linux and macOS

### Manual

The CLI is a bash script that only depends on `git` so you can just download it
and make it executable by running `chmod +x <path_to_script>`.

### Nix (flake)

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    git-auto-sync = {
      url = "github:bigolu/git-auto-sync";
      inputs = {
        nixpkgs.follows = "nixpkgs";

        # Remove development dependencies
        devshell.follows = "";
        flake-compat.follows = "";
        devshell-modules.follows = "";
      };
    };
  };

  outputs = inputs:
    let
      # You can use the package
      package = inputs.git-auto-sync.packages.${system}.default;
      # Or the overlay
      packageFromOverlay = (import inputs.nixpkgs { overlays = [inputs.git-auto-sync.overlays.default]; }).git-auto-sync;
    in
    {
      # ...
    }
}
```

## Usage

### Setting up the git hooks

Run the following command:

```bash
git-auto-sync install <sync_command>...
```
  
Where `sync_command` is the command that does the syncing.

Example: `git-auto-sync install uv sync`

### Running the sync command

The environment variable `IN_GIT_AUTO_SYNC` will be set to `true`.

The environment variable `GIT_AUTO_SYNC_LAST_COMMIT` will be set to the hash of last synced commit or an empty string
if no commit has been synced. This can be used by the sync command to calculate
the files that differ between a new commit that's being synced with and the
last one. Then it can use this file list to determine what
needs to be synced.

[lefthook]: https://github.com/evilmartians/lefthook
