{ pkgs, stdenv, mypy, python3 }:
stdenv.mkDerivation {
	buildInputs = [ python3 mypy ];
	name = "nix-pin";
	version = "0.1.0";
	src = ./local.tgz;
	buildPhase = ''
		mypy bin/*
	'';
	installPhase = ''
		mkdir "$out"
		cp -r bin "$out"
		cp -r share "$out"
	'';
}
