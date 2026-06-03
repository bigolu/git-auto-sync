source_url \
  'https://raw.githubusercontent.com/bigolu/direnv-devshell/c063e0605481ec97cfec78abd8dd9ead0746318d/src/main.bash' \
  'sha256-J1DKZGjz/XiKz430g8pN5CZnqa7kyZ/RIlnV+rTufas='
DEVSHELL_DIRENV_FALLBACK=true use_devshell --file nix/flake-compat.nix outputsForCurrentSystem.devShells.dev
