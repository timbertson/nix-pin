{ pkgs, stdenv, mypy, python3 }:
let self = stdenv.mkDerivation {
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
