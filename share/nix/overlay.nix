{ callPins }:
self: super:
# prevent double-application of nix pin overlay
if (super.nixPinOverlayEnabled or false) then {} else
	let
		lib = super.lib;
		pins = callPins self.callPackage;

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
	}
