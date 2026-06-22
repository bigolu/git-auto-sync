{ pkgs, ... }:
let
  inherit (pkgs) bash lib resholve;
  inherit (lib) getExe;

  pname = "git-auto-sync";
  dependencies = with pkgs; [
    git
  ];
in
resholve.mkDerivation {
  inherit pname;
  version = "0.1.0";
  src = ../../git-auto-sync.bash;
  meta.mainProgram = pname;
  passthru.devshellModule = { devshell.packages = [bash] ++ dependencies; };
  dontUnpack = true;
  installPhase = ''
    install -D $src $out/bin/${pname}
  '';
  solutions.default = {
    scripts = [ "bin/${pname}" ];
    interpreter = "${bash}/bin/bash";
    inputs = dependencies;
    execer = [
      "cannot:${getExe pkgs.git}"
    ];
    keep = {
      "$sync_command" = true;
    };
  };
}
