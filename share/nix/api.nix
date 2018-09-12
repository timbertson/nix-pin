let defaults = import ./defaults.nix; in
{
	pkgs ? defaults.pkgs,
	pinConfig ? defaults.pinConfig
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
			let
				parseEnvList = name: lib.filter (x: x != "") (lib.splitString ":" (builtins.getEnv name));
				included = parseEnvList "NIX_PIN_INCLUDE";
				excluded = parseEnvList "NIX_PIN_EXCLUDE";
				matchesAny = specs: name: lib.any (spec: spec == "*" || name == spec) specs;
				shouldInclude = (if included == [] then lib.const true else matchesAny included);
				shouldExclude = matchesAny excluded;
				allPins = import pinConfig { inherit lib importFromArchive; };
				filteredPins = lib.filterAttrs (name: value:
					if shouldInclude name then (
						if shouldExclude name then
							lib.info "<pin-excluded:${name}> by $NIX_PIN_EXCLUDE" false
						else
						true
					) else (
						lib.info "<pin-excluded:${name}> by $NIX_PIN_INCLUDE" false
					)
				) allPins;
			in
			filteredPins
		else
			{};

	warnPinEvaluated = name: pin: val:
		lib.info
			"<pin:${name}> ${pin.spec.revision} (${pin.spec.root}#${pin.spec.path or "default.nix"})"
			val;

	overrideSource = src: drv:
		# prefer overrideAttrs where possible
		if lib.isDerivation drv then (
			if drv ? overrideAttrs then
				drv.overrideAttrs (o: { inherit src; allowSubstitutes = false; })
			else
				lib.overrideDerivation drv (o: { inherit src; allowSubstitutes = false; })
		) else drv;

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
					overrideSource pin.src drv
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

				newScope = args: super.newScope (args // pins); # pins take precedence over autoArgs
				callPackages = fn: args: super.callPackages fn ((argIntersection fn pins) // args); # pins take a backseat to explicit args

				# Note: callPackage is _already_ defined in terms of `self.newScope`, so
				#       there's no need to override it.
				# callPackage = fn: args: super.callPackage fn (pins // args); # pins take a backseat to explicit args
			};
	
	call = { buildPin, buildPath, callArgs ? {} }:
		if buildPin != null then (
			lib.getAttr buildPin pins
		) else if buildPath != null then (
			augmentedPkgs.callPackage buildPath callArgs
		) else augmentedPkgs;
in
{
	inherit pins augmentedPkgs call overlayFn overrideSource;
	inherit (augmentedPkgs) callPackage;
}

