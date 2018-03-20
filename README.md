# nix-pin:

### Why?

Nixpkgs is a great set of canonical packages. But when working on one or more development versions of packages, it can be awkward.

Examples:

### `libfoo`'s nix expression doesn't live with the `libfoo` source code

The canonical version of `libfoo/default.nix` lives in nixpkgs, but if you're the author of `libfoo` you likely want to maintain this file in your source tree. That way, you have the correct build instructions for the actual version you're developing, without having to merge in-development changes into `nixpkgs`.

### Testing a full `nix-build` of your master branch

`nix-shell` works well for development changes, but you should also test that a full `nix-build` works, particularly if you're changing the build process. By default, this builds the archive specified in your nix expression, which is typically a release tarball. It's awkward to refer to "the current checkout" in a clean way. If you just use `./`, your entire workspace is copied into the /nix store every time you change anything. You also need to remember to set this back to a real `src` attribute for release. And finally, using a directory in development and a tarball for release can cause build inconsistencies.

### Testing multiple inter-dependent packages

If `libFoo` depends on `libBar`, you may need to make changes to `libBar` by building `libFoo` against your in-development version of `libBar`. This is not trivial with nix - typically `nix-shell` will get you the release of `libBar` as it appears in your nixpkgs channel.

# Alternatives:

### "Just fork nixpkgs"

All of these problems can be achieved by forking `nixpkgs` and using your local version, replacing real sources with locally-built tarballs from development sources, etc. But there are a number of problems with this:

 - You can't use `nix-channel`
 - There's no good workflow (that I know of). Building tarballs for specific in-development versions and using them in `src` attributes is tedious and easy to forget a step unless you script it, but it's also not well-suited to a generic scripting approach.
 - It doesn't compose. If you're working on multiple open source projects which take this approach, you'll end up with multiple long-running branches of `nixpkgs`. If you want to integrate multiple projects, you'll need to be handy with `git merge` and hope that the individual `nixpkgs` versions used actually vaguely compatible. It's also very hard to see what packages diverge from their upstream versions after a few merges.

# Rationale

The name comes from the `pin` functionality in `opam` and other package managers. The idea is that you mostly use the official repository for your packages, but sometimes you need to "pin" a given package to a specific version (or directory). This lets you pretend your local version is the official one, allowing you to test out packaging actions and inject your modified version into dependant packages.

# When is a pin used?

Any time `callPackage` is used, there are two sets of arguments - the implicit arguments which are taken from the scope as needed, and the explicit argument. e.g:

```
pkgs.callPackage default.nix { foo = true; }
```

In this case `pkgs` are the implicit arguments, and `foo` is the only explicit argument.

Under `nix-pin`, all your active pins are injected with higher priority than the scope, but lower priority than explicit arguments. Note that the pin name becomes the argument name - if you call a pin "foo", then it will automatically be substituted for _every_ `foo` in _every_ `callPackage` invocation. Typically names are unique enough that you're unlikely to encounter a naming conflict, although you may encounter issues if this is not the case. (TODO: are there ways to scope this injection more finely?)

# Usage:

### build / shell

```
nix-pin [build|shell] [--path path/to/default.nix] [ ... ]
```

Like `nix-build` / `nix-shell`, but with all pins activated. A note is printed for each pin which is being used.

### manage pins:

```
# list pins (and pinned versions)
nix-pin status

# update a pin with the current workspace content (or a specific commit), so it will be used as a dependency for other (pinned) projects
nix-pin update [name] [--revision COMMIT]

# add a named pin, where the name specifies the attribute path where it should be overlaid (on `pkgs`)
nix-pin add vdoml root [--path path-to-nix-file]
```

# GC roots:

TODO, nothing is registered as a GC root yet. Pinned packages will be pruned on GC.

---

To enable pins in a project's nix-shell by default, we can use:

```
# shell.nix
with (import <nixpkgs> {}):
nixPin.callWithPins ./default.nix {}
```

(but you can also just use `nix-pin shell` without explicitly referencing nixPin in your expression)
