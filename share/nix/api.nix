{
	pkgs ? (import ./defaults.nix).pkgs,
	pinConfig ? (import ./defaults.nix).pinConfig
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

	callPinsWith = callPackage:
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
	
	pins = callPinsWith pkgs.callPackage;

	augmentedPkgs = import pkgs.path { overlays = [ overlayFn ]; };
	
	overlayFn = self: super:
		# prevent double-application of nix pin overlay
		if (super.nixPinOverlayEnabled or false) then {} else
			let
				lib = super.lib;
				pins = callPinsWith self.callPackage;

				argIntersection = func: args:
					# don't provide pins which aren't accepted by `func`:
					let
						fn = if lib.isFunction func then func else import func;
					in
					builtins.intersectAttrs (lib.functionArgs fn) args;
			in
			{
				nixPinOverlayEnabled = true;

				# These three functions form the basis of callPackage:
				#  - callPackage: the function itself
				#  - newScope: used to build further `callPackage` functions
				#  - callPackages: callPackage for an attribute set of derivations
				# These are all (currently) defined in splice.nix.
				# Note: callPackage is _already_ defined in terms of `self.newScope`, so
				#       there's no need to override it.

				newScope = args: super.newScope (args // pins); # pins take precedence over autoArgs
				callPackages = fn: args: super.callPackages fn ((argIntersection fn pins) // args); # pins take a backseat to explicit args
				# callPackage = fn: args: withWarning (super.callPackage fn (pins // args)); # pins take a backseat to explicit args
			};
	
	call = { buildPin, buildPath }:
		if buildPin != null then (
			lib.getAttr buildPin pins
		) else if buildPath != null then (
			augmentedPkgs.callPackage buildPath {}
		) else (lib.warn "buildPath or buildPin attribute required" (assert false; null));
in
{
	inherit pins augmentedPkgs call overlayFn;
	inherit (augmentedPkgs) callPackage;
}

