{ pkgs, stdenv, fetchFromGitHub, mypy, python3 }:
let self = stdenv.mkDerivation rec {
  buildInputs = [ python3 mypy ];
  name = "nix-pin-${version}";
  version = "0.1.0";
  src = fetchFromGitHub {
    owner = "timbertson";
    repo = "nix-pin";
    rev = "version-0.1.0";
    sha256 = "009hr9pckprpj2j1ighjc8956ijiy9bb8dyf3vgxyqzkyafn83s3";
  };
  buildPhase = ''
    mypy bin/*
  '';
  installPhase = ''
    mkdir "$out"
    cp -r bin share "$out"
  '';
  passthru = {
    callWithPins = path: { home ? builtins.getEnv "HOME", ... } @ args:
      let
        callArgs = removeAttrs args ["home"];
        pinConfig = /. + "${home}/.config/nix-pin/pins.nix";
      in
      import "${self}/share/nix/run.nix" {
        inherit pkgs pinConfig;
        pinPath = path;
        callArgs = args;
      };
  };
}; in self
