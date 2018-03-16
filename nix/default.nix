{ pkgs, stdenv }:
stdenv.mkDerivation {
	buildInputs = [ pkgs.python3 ];
	name = "nix-pin";
	version = "0.1.0";
	src = ./local.tgz;
	passthru = import ./api.nix { inherit pkgs; };
	installPhase = ''
		mkdir "$out"
		cp -r bin "$out"
	'';
}
