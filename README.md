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

`git-auto-sync` should be called from the git hooks `post-rewrite`, `post-merge`, `post-checkout`, and `post-commit`. The call has the form:

```bash
env GIT_AUTO_SYNC_HOOK_NAME=<hook_name> git-auto-sync <git_hook_args>... -- <sync_command>...
```

- The environment variable `GIT_AUTO_SYNC_HOOK_NAME` should be set to the name of the git hook being executed (`<hook_name>`).

- `git_hook_args` are the arguments that were passed to the git hook.
  
- `sync_command` is the command that should be run to do the syncing.

Here's an example of setting up the git hooks using the hook manager [lefthook][lefthook]:

```yaml
# {0} will be replaced with the arguments that were passed to the git hook.

post-rewrite:
  jobs:
    - name: sync
      run: GIT_AUTO_SYNC_HOOK_NAME='post-rewrite' git-auto-sync {0} -- lefthook run sync

post-merge:
  jobs:
    - name: sync
      run: GIT_AUTO_SYNC_HOOK_NAME='post-merge' git-auto-sync {0} -- lefthook run sync

post-checkout:
  jobs:
    - name: sync
      run: GIT_AUTO_SYNC_HOOK_NAME='post-checkout' git-auto-sync {0} -- lefthook run sync

post-commit:
  jobs:
    - name: sync
      run: GIT_AUTO_SYNC_HOOK_NAME='post-commit' git-auto-sync {0}
```

### Running the sync command

The environment variable `GIT_AUTO_SYNC_LAST_COMMIT` will be set to the hash of last synced commit or an empty string
if no commit has been synced. This can be used by the sync command to calculate
the files that differ between a new commit that's being synced with and the
last one. Then it can use this file list to more granularly determine what
needs to be synced.

[lefthook]: https://github.com/evilmartians/lefthook
