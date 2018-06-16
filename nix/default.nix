{ lib, pkgs, stdenv, fetchFromGitHub, mypy, python3, nix, git, makeWrapper }:
let self = stdenv.mkDerivation rec {
  name = "nix-pin-${version}";
  version = "0.3.3";
  src = fetchFromGitHub {
    owner = "timbertson";
    repo = "nix-pin";
    rev = "version-0.3.3";
    sha256 = "0nk3azvqfj41f0gka4b2kyigjg22mb25sykkslb73g0kj2fx2p29";
  };
  buildInputs = [ python3 mypy makeWrapper ];
  checkPhase = ''
    mypy bin/*
  '';
  installPhase = ''
    mkdir "$out"
    cp -r bin share "$out"
    wrapProgram $out/bin/nix-pin \
      --prefix PATH : "${lib.makeBinPath [ nix git ]}"
  '';
  passthru =
    let
      defaults = import "${self}/share/nix/defaults.nix";
    in {
      api = { pinConfig ? defaults.pinConfig }:
        let impl = import "${self}/share/nix/api.nix" { inherit pkgs pinConfig; }; in
        { inherit (impl) augmentedPkgs pins callPackage; };
      updateScript = ''
        set -e
        echo
        cd ${toString ./.}
        ${pkgs.nix-update-source}/bin/nix-update-source \
          --prompt version \
          --replace-attr version \
          --set owner timbertson \
          --set repo nix-pin \
          --set type fetchFromGitHub \
          --set rev 'version-{version}' \
          --modify-nix default.nix
      '';
    };
  meta = with stdenv.lib; {
    homepage = "https://github.com/timbertson/nix-pin";
    description = "nixpkgs development utility";
    license = licenses.mit;
    maintainers = [ maintainers.timbertson ];
    platforms = platforms.all;
  };
}; in self
