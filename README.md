Nixpin:

# Why?

Nixpkgs is a great set of canonical packages. But when working on one or more development versions of packages, it can be awkward.

Examples:

### `libfoo`'s nix expression doesn't live with the `libfoo` source code

The canonical version of `libfoo/default.nix` lives in nixpkgs, but if you're the author of `libfoo` you would probably prefer to maintain this file in your source tree. That way, you have the correct build instructions for the actual version you're developing, without having to merge in-development changes into `nixpkgs`.

### Testing a full `nix-build` of your master branch

`nix-shell` works well for development changes, but you should also test that a full `nix-build` works, particularly if you're changing the build process. By default, this builds the archive specified in your nix expression, which is typically a release tarball. It's awkward to refer to "the current checkout" in a clean way. If you just use `./`, your entire workspace is copied into the /nix store every time you change anything. You also need to remember to replace this with a real `src` attribute for release. And finally, using a directory in development and a tarball for release can cause build inconsistencies.

### Testing multiple inter-dependent packages

If `libFoo` depends on `libBar`, you may need to make changes to `libBar` by building `libFoo` against your in-development version of `libBar`. This is not trivial with nix - typically `nix-shell` will get you the current release of `libBar`.

# Alternatives:

### "Just fork nixpkgs"

All of these problems can be achieved by forking `nixpkgs` and using your local version, replacing real sources with locally-built tarballs from development sources, etc. There are two problems with this:

 - There's no good workflow (that I know of). Building tarballs for specific in-development versions and using them in `src` attributes is tedious and easy to forget a step unless you script it (but this is difficult since the set of packages you care about overriding changes depending on what you're working on).
 - It doesn't compose. If you're working on multiple open source projects which take this approach, you'll end up with multiple long-running chanches of `nixpkgs`. If you want to integrate multiple projects, you'll need to be handy with `git merge` and hope that the individual `nixpkgs` versions used actually vaguely compatible. It's also very hard to see what packages diverge from their upstream versions after a few merges.

# Usage:

### build

nix-pin build [pkg]

Like `nix-build`, but with all pins overlaid on `pkgs`. If `pkg` is not given, infer it from current directory.
This uses the pinned version of all deps, but always builds the latest version of the package in question

Options:

`--isolated-pin`: enable only the named pin
`--disable-pin NAME`
`--enable-pin NAME` (reenable an additional pin if using --isolated-pin)
`--pin-attr [pkg] key value` (pkg defaults to the subject)
`--update-pins`: update all active pins before building
`--update-pin NAME`: update all pins before building

### manage pins:

```
# list pins (and pinned versions)
nix-pin show [name]

# is the pin outdated compared to the workspace?
nix-pin status [name]

# update a pin with the current workspace content (or a specific commit), so it will be used as a dependency for other (pinned) projects
nix-pin update [name] [--revision COMMIT]

# add a named pin, where the name specifies the attribute path where it should be overlaid (on `pkgs`)
nix-pin add ocamlPackages.vdoml [path-to-nix-file]
(TODO: should multiple package paths be allowed, as aliases?)

# modify a pin's custom config:
nix-pin config [pkgname] --attr debugMode true
nix-pin config [pkgname] --stringAttr mode mirage-unix
```


-------
# Layout (implementation detail)

$HOME/.config/nix-pin/pins/ocamlPackages.vdoml/spec.json
# {
#    "root": "/home/tim/dev/vdoml/", # git workspace
#    "path": "pin.nix", # path within workspace. If `null`, try defaults of [pin.nix; default.nix}
#    "revision": "ABCD-SHA-1", # currently cached revision
#    "attrs": { ... }
# }
$HOME/.cache/nix-pin/pins/ocamlPackages.vdoml/{SHA}.tgz # (export of $SHA)

To update atomically:
# generate {NEW_SHA}.tgz
# write config
# write updated pins.nix?
# delete all other archive files


# GC roots (implementation detail):

TODO: When adding a pin, should we add an indirect GC root to that implementation?

---

nix-pin:

for each configured pin:
 - current package?
   - update tarball (using git workspace stash stuff)
 - otherwise:
   - if tarball is missing, build it
 - generate nix snippet override, which imports `<tarball>/path-to-nixexpr.nix`, and:
   - overrides its source
   - uses pkgs.callPackage to import, with extra attributes from JSON (and commandline if current pin?)

overlay `pkgs` based on attribute(s) from json. provide as `nixPin.pkgs` (TODO: also overridden in ~/nixpkgs/.config.nix ??)

To enable pins in a project's nix-shell by default, we can use:

# shell.nix
{ pkgs }:
pkgs.callPin "vdoml" ./default.nix {
	# ( passes overlaid `pkgs`)
	# NOTE: this passes attrs through, should there be an alternate callPackage when that's not wanted?
};

If you don't want to explicitly enable pins in your `shell.nix`, we provide `nix-pin shell` which does this for you. This also allows using nix-pin in projects which aren't pin-aware.
