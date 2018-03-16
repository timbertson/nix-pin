{ pkgs }:
# nix API, augmented as `passthru` attributes in default.nix
let
	lib = pkgs.lib;
	home = builtins.getenv "HOME";
	importFromArchive = archive: path:
		let
			drv = pkgs.stdenv.mkDerivation {
				name = "drv-1";
				buildCommand = ''
					mkdir "$out"
					tar xzf -C $out --strip-components=1 "${archive}"
				'';
			};
		in
		"${drv}/${path}";
	pinConfig = "${home}/.config/nix-pin/pins.nix";
	toPath = s: /. + s;
	pinSpecs = pkgs.callPackage (toPath (pinConfig)) { inherit lib importFromArchive; };

	callPins = attrs: callPackage: lib.mapAttrs (
		name: pin:
			let drv = callPackage pin.drv (attrs // pin.attrs); in
			overrideSource pin drv
	) pinSpecs;

	withPinSpec = name: pinFn: default:
		with lib;
		if (hasAttr name pinSpecs)
		then pinFn (getAttr name pinSpecs)
		else default;

	overrideSource = pin: drv:
		lib.overrideDerivation drv (o: { src = pin.src; });

	pins = callPins {} pkgs;
	overlayPath = ./overlay.nix;
	augmentedPkgs = import pkgs.path { overlay = [ (import overlayPath) ]; };
in
{
	pkgs = augmentedPkgs;
	inherit (augmentedPkgs) callPackage;

	inherit pins callPins overlayPath;

	# for use in a pin's own shell.nix. Notably it does _not_ override the
	# package derivation itself, only the source.
	callPin = { name, path, attrs ? {}, callPackage ? augmentedPkgs.callPackage }:
		withPinSpec name
			# if pin defined:
			(pin:
				let attrsMerged = (attrs // pins // pin.attrs); in
				overrideSource pin (callPackage path attrsMerged)
			)
			# else
			(callPackage path attrs)
	;
}
