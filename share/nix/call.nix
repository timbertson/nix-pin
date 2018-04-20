{
	pkgs ? (import ./defaults.nix).pkgs,
	pinConfig ? (import ./defaults.nix).pinConfig,
	buildPin,
	buildPath,
	buildArgs ? {} # NOTE: not exposed via nix-pin binary yet
}:

(import ./api.nix { inherit pkgs pinConfig; }).call { inherit buildPin buildPath buildArgs; }
