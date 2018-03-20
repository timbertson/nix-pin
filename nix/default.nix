{ pkgs, stdenv, fetchFromGitHub, mypy, python3 }:
let self = stdenv.mkDerivation rec {
  name = "nix-pin-${version}";
  version = "0.1.1";
  src = fetchFromGitHub {
    owner = "timbertson";
    repo = "nix-pin";
    rev = "version-0.1.1";
    sha256 = "01yhq1n5rc5y5qfwapnzi3dmg2pr34qmvylb8v59rddb9wszd8l4";
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
