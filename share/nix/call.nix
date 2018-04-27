{
	pkgs ? (import ./defaults.nix).pkgs,
	pinConfig ? (import ./defaults.nix).pinConfig,
	buildPin,
	buildPath,
	callArgs
}:

(import ./api.nix { inherit pkgs pinConfig; }).call { inherit buildPin buildPath callArgs; }
