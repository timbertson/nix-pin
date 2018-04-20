{
	pkgs = import <nixpkgs> {};
	pinConfig =
		let
			HOME = builtins.getEnv "HOME";
			NIX_PIN_CONFIG = builtins.getEnv "NIX_PIN_CONFIG";
		in
		if NIX_PIN_CONFIG != "" then NIX_PIN_CONFIG
		else (
			"${HOME}/.config/nix-pin/pins.nix"
		);
}
