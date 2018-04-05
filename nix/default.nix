{ pkgs, stdenv, fetchFromGitHub, mypy, python3 }:
let self = stdenv.mkDerivation rec {
  name = "nix-pin-${version}";
  version = "0.1.2";
  src = fetchFromGitHub {
    owner = "timbertson";
    repo = "nix-pin";
    rev = "version-0.1.2";
    sha256 = "1zwfb5198qzbjwivgiaxbwva9frgrrqaj92nw8vz95yi08pijssh";
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
