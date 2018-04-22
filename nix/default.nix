{ pkgs, stdenv, fetchFromGitHub, mypy, python3 }:
let self = stdenv.mkDerivation rec {
  name = "nix-pin-${version}";
  version = "0.2.1";
  src = fetchFromGitHub {
    owner = "timbertson";
    repo = "nix-pin";
    rev = "version-0.2.1";
    sha256 = "1az3zjpw6bg77ky6macx13ympfxvd6xcw2kvsy3jpsrw2c70vd1c";
  };
  buildInputs = [ python3 mypy ];
  buildPhase = ''
    mypy bin/*
  '';
  installPhase = ''
    mkdir "$out"
    cp -r bin share "$out"
  '';
  passthru =
    let api = import "${self}/share/nix/api.nix" { inherit pkgs; }; in
    {
      inherit (api) augmentedPkgs pins callPackage;
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
