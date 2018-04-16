{
	pkgs ? import <nixpkgs> {},
	pinConfig ? "${builtins.getEnv "HOME"}/.config/nix-pin/pins.nix",
	buildPin,
	buildPath,
	buildArgs ? {} # NOTE: not exposed via nix-pin binary yet
}:

let
	lib = pkgs.lib;
	importFromArchive = archive: path:
		let
			drv = pkgs.stdenv.mkDerivation {
				name = "drv-1";
				buildCommand = ''
					mkdir "$out"
					echo "Importing from archive: ${archive}"
					tar xzf "${archive}" -C $out --strip-components=1
				'';
				allowSubstitutes = false;
			};
		in
		"${drv}/${path}";

		pinSpecs = if builtins.pathExists pinConfig
			then
				(import pinConfig { inherit lib importFromArchive; })
			else
				{};

	warnPinEvaluated = name: pin: val:
		lib.info
			"Using pin: ${name}@${pin.spec.revision} (${pin.spec.root})"
			val;

	overrideSource = pin: drv:
		lib.overrideDerivation drv (o: { src = pin.src; allowSubstitutes = false; });

	callPins = callPackage:
		let
			pins = lib.mapAttrs (
				name: pin:
					let
						drvFn = import pin.drv;
						argIntersection = args:
							builtins.intersectAttrs (lib.functionArgs drvFn) args;
						pinArgs = argIntersection (pins // pin.attrs);
						drv = warnPinEvaluated name pin (callPackage drvFn pinArgs);
					in
					overrideSource pin drv
			) pinSpecs;
		in
		pins;

	augmentedPkgs = import pkgs.path { overlays = [
		(import ./overlay.nix { inherit callPins; }) ]; };

	target =
		if buildPin != null then (
			lib.getAttr buildPin (callPins pkgs.callPackage)
		) else if buildPath != null then (
			augmentedPkgs.callPackage buildPath buildArgs
		) else (lib.warn "buildPath or buildPin attribute required" (assert false; null));
in
	target
