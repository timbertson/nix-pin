{ pkgs, stdenv, fetchFromGitHub, mypy, python3 }:
let self = stdenv.mkDerivation rec {
  name = "nix-pin-${version}";
  version = "0.1.0";
  src = fetchFromGitHub {
    owner = "timbertson";
    repo = "nix-pin";
    rev = "version-0.1.0";
    sha256 = "009hr9pckprpj2j1ighjc8956ijiy9bb8dyf3vgxyqzkyafn83s3";
  };
  buildInputs = [ python3 mypy ];
  buildPhase = ''
    mypy bin/*
  '';
  installPhase = ''
    mkdir "$out"
    cp -r bin share "$out"
  '';
  passthru = {
    callWithPins = path: args:
      import "${self}/share/nix/call.nix" {
        inherit pkgs path args;
      };
  };
}; in self
