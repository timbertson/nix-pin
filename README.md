# Deprecation warning:

`nix-pin` is not under active development. [nix-wrangle](https://github.com/timbertson/nix-wrangle/) is its spiritual successor, with many more features.

----

# nix-pin:

### Why?

Nixpkgs is a great set of canonical packages. But when working on one or more development versions of packages, it can be awkward.

Examples:

### `libfoo`'s nix expression doesn't live with the `libfoo` source code

The canonical version of `libfoo/default.nix` lives in nixpkgs, but if you're the author of `libfoo` you likely want to maintain this file in your source tree. That way, you have the correct build instructions for the actual version you're developing, without having to merge in-development changes into `nixpkgs`.

### Testing a full `nix-build` of your master branch

`nix-shell` works well for development changes, but you should also test that a full `nix-build` works, particularly if you're changing the build process. By default, this builds the archive specified in your nix expression, which is typically a release tarball. It's awkward to refer to "the current checkout" in a clean way. If you just use `./`, your entire workspace is copied into the nix store every time you change anything. You also need to remember to set this back to a real `src` attribute for release. And finally, using a directory in development and a tarball for release can cause build inconsistencies.

### Testing multiple inter-dependent packages

If `libFoo` depends on `libBar`, you may need to make changes to `libBar` by building `libFoo` against your in-development version of `libBar`. This is not trivial with nix - typically `nix-shell` will get you the release of `libBar` as it appears in your nixpkgs channel. You'd need to modify `libFoo` to point to your local `libBar`, and remember to undo that before publishing anything.

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

Under `nix-pin`, all your active pins are injected with higher priority than the automatic scope, but lower priority than explicit arguments. Note that the pin name becomes the argument name - if you call a pin "foo", then it will automatically be substituted for _every_ `foo` in _every_ `callPackage` invocation. Typically names are unique enough that you're unlikely to encounter a naming conflict, although you may encounter issues if this is not the case.

# Usage:

### manage pins:

```
# add a named pin, where the name specifies the attribute path where it should be overlaid (on `pkgs`)
nix-pin create vdoml root [--path path-to-nix-file]

# list pins (and pinned versions)
nix-pin status

# update a pin with the current workspace content (or a specific commit), so it will be used as a dependency for other (pinned) projects
nix-pin update [name] [--revision COMMIT]
```

### build / shell

```
nix-pin [build|shell] [--path path/to/default.nix] [ nix-build-arguments ]
```

Like `nix-build` / `nix-shell`, but with all pins activated. A note is printed for each pin which is being used.

## GC roots:

TODO, nothing is registered as a GC root yet. Pinned packages will be pruned on GC.

---

# Full usage example:

(**Note:** you'll need at least nix-pin v0.3.0 to follow along, check your version with `nix-instantiate --eval -A nix-pin.version '<nixpkgs>'` or `which nix-pin`)

First, get a shell with the tools we'll need:

```
$ nix-shell -p git nix nix-pin
```

Now get the GNU `sed` source code.

`sed` isn't the best example since it uses autotools, so its release archives include generated files (like `./configure`) which aren't present in the git repo, and which require a lot of extra dependencies to generate.

`nix-pin` is intended for repositories which are directly buildable, so for the sake of simplicity I'll be using a repo which inludes all the generated files, as well as the `sed` nix expression copied from nixpkgs (in default.nix).

(why am I using `sed` if it's a bad example? Because it's a simple program that most people are familiar with, and it's used in many other derivations)

```
$ git clone https://github.com/timbertson/nix-pin-example-sed.git
Cloning into 'nix-pin-example-sed'...
remote: Counting objects: 959, done.
remote: Compressing objects: 100% (656/656), done.
remote: Total 959 (delta 216), reused 959 (delta 216), pack-reused 0
Receiving objects: 100% (959/959), 2.01 MiB | 413.00 KiB/s, done.
Resolving deltas: 100% (216/216), done.
```

```
$ cd nix-pin-example-sed/
```

this repo includes a copy of the sed `.nix` file from nixpkgs, to make it self-contained:

```
$ head default.nix
{ stdenv, fetchurl, perl }:

stdenv.mkDerivation rec {
  name = "gnused-${version}";
  version = "4.4";

  src = fetchurl {
    url = "mirror://gnu/sed/sed-${version}.tar.xz";
    sha256 = "0fv88bcnraixc8jvpacvxshi30p5x9m7yb8ns1hfv07hmb2ypmnb";
  };
```

Note that the `src` used in this derivation is the official gnused 4.4 release, but we've made a trivial modification in this repo:

```
$ git show 1a2e134fdc3f4cf2e23c7a4a3b3aa8155ac126f1
commit 1a2e134fdc3f4cf2e23c7a4a3b3aa8155ac126f1 (HEAD -> master, origin/master, origin/HEAD)
Author: Tim Cuthbertson <tim@gfxmonk.net>
Date:   Sun Apr 29 18:37:38 2018 +1000

    add unnecessary output to sed

diff --git a/sed/sed.c b/sed/sed.c
index 15faff0..a627381 100644
--- a/sed/sed.c
+++ b/sed/sed.c
@@ -229,6 +229,8 @@ main (int argc, char **argv)
   int return_code;
   const char *cols = getenv("COLS");
 
+  fprintf(stderr, "Welcome to sed, the streamiest editor!\n");
+
   program_name = argv[0];
   initialize_main (&argc, &argv);
 #if HAVE_SETLOCALE
```

### So, let's get pinning!

```
$ nix-pin create gnused .
INFO:root:Updating: gnused ...
INFO:root: - gnused: init at 1a2e134fdc3f4cf2e23c7a4a3b3aa8155ac126f1
INFO:root:Created: {'root': '~/dev/nix/nix-pin/example/nix-pin-example-sed', 'revision': '1a2e134fdc3f4cf2e23c7a4a3b3aa8155ac126f1'}
INFO:root:Updating archive for gnused@1a2e134fdc3f4cf2e23c7a4a3b3aa8155ac126f1
```

First things first: build our local source code using the build instructions in `default.nix` (which we copied from nixpkgs):

```
$ nix-pin build
1 pin(s) configured
  - gnused: 1a2e134f (/home/tim/dev/nix/nix-pin/example/nix-pin-example-sed#default.nix)
DEBUG:root:found pin gnused for directory /home/tim/dev/nix/nix-pin/example/nix-pin-example-sed
DEBUG:root:Updating gnused
INFO:root:Updating: gnused ...
INFO:root: - gnused unchanged (1a2e134fdc3f4cf2e23c7a4a3b3aa8155ac126f1)
INFO:root: + nix-build --argstr pinConfig /home/tim/.config/nix-pin/pins.nix --arg buildPath null --argstr buildPin gnused --arg callArgs {} /nix/store/i94h8xfzwsr83lnwlhv2snbzli0sk8p2-nix-pin-0.3.0/share/nix/call.nix
trace: INFO: <pin:gnused> 1a2e134fdc3f4cf2e23c7a4a3b3aa8155ac126f1 (~/dev/nix/nix-pin/example/nix-pin-example-sed#default.nix)
building '/nix/store/8xn0vkv8ckk7n1np84y5xiqdrpzmrjrx-drv-1.drv'...
Importing from archive: /nix/store/qldjwg3zdx8yy14q9bjhas3axk7iwdm7-gnused-1a2e134fdc3f4cf2e23c7a4a3b3aa8155ac126f1.tgz
these derivations will be built:
  /nix/store/q1ym34g0mz8znhj1r2av338hy0437iyf-gnused-4.4.drv
building '/nix/store/q1ym34g0mz8znhj1r2av338hy0437iyf-gnused-4.4.drv'...
# ( ... )
/nix/store/vsnra3wib8szysis6w8cwrrc05w1xkmy-gnused-4.4
```

The build is stored in a `result` symlink (we're using `nix-build` under the hood), let's check that it built our modified version:

```
$ ./result/bin/sed --help
Welcome to sed, the streamiest editor!
Usage: ./result/bin/sed [OPTION]... {script-only-if-no-other-script} [input-file]...
# ( ... )
```

Perfect - it built our local source, rather than the official archive specified in `default.nix`.

### Using pins as dependencies

Now for the next step, let's use our modified `sed` in the rest of nixpgs. I poked around some derivations, and found that a program called `cdecl` is pretty simple, and [uses `gnused` in its build process](https://github.com/NixOS/nixpkgs/blob/cd960b965f2587efbe41061a4dfa10fc72a28781/pkgs/development/tools/cdecl/default.nix#L12):

```
$ nix-pin build --path '<nixpkgs>' --no-out-link --show-trace -A cdecl
1 pin(s) configured
  - gnused: 1a2e134f (/home/tim/dev/nix/nix-pin/example/nix-pin-example-sed#default.nix)
INFO:root: + nix-build --argstr pinConfig /home/tim/.config/nix-pin/pins.nix --arg buildPath null --arg buildPin null --arg callArgs {} --no-out-link --show-trace -A cdecl /nix/store/i94h8xfzwsr83lnwlhv2snbzli0sk8p2-nix-pin-0.3.0/share/nix/call.nix
trace: INFO: <pin:gnused> 1a2e134fdc3f4cf2e23c7a4a3b3aa8155ac126f1 (~/dev/nix/nix-pin/example/nix-pin-example-sed#default.nix)
these derivations will be built:
  /nix/store/b5kdjz15nsliql3gxvhfkw4jvjf6xlk8-cdecl-2.5.drv
building '/nix/store/b5kdjz15nsliql3gxvhfkw4jvjf6xlk8-cdecl-2.5.drv'...
# ( ... )
building
Welcome to sed, the streamiest editor!
# ( ... )
/nix/store/ij0diif9x6m151wfgh0d6l4m9r6hnvgn-cdecl-2.5
```

Great! Without doing anything special, our `gnused` got picked up and used as a build-time dependency in other packages. The exact algorithm simply matches a pin name (here, `gnused`) against the name of arguments supplid by `callPackage`. If a pin matches an automatically supplied argument, you'll get the pin instead.

We could have done this by modifying `packageOverrides` in `~/.nixpkgs/config.nix` to make our sed the one and only sed, but that gets inconvenient, as you need to maintain the correct `src` (you'll need to keep making some kind of archive and updating `sha256` on every code modification). You'd then want to remove that any time you contribute to `nixpkgs`, otherwise your builds will not be reproducible (since nobody else has those same overrides).

To show how easy it is to build modifications with `nix-pin`, let's make that header a bit less lame:

```
$ sed -i 's/streamiest/stream/' sed/sed.c
$ nix-pin build
1 pin(s) configured
  - gnused: 1a2e134f (/home/tim/dev/nix/nix-pin/example/nix-pin-example-sed#default.nix)
DEBUG:root:found pin gnused for directory /home/tim/dev/nix/nix-pin/example/nix-pin-example-sed
DEBUG:root:Updating gnused
INFO:root:Updating: gnused ...
INFO:root: - gnused: updated to cf5a401bcbbbf7d6942879fdb7b86108f9c7f77c (from 1a2e134fdc3f4cf2e23c7a4a3b3aa8155ac126f1)
INFO:root:Updating archive for gnused@cf5a401bcbbbf7d6942879fdb7b86108f9c7f77c
INFO:root:removing cache path /home/tim/.cache/nix-pin/gnused-1a2e134fdc3f4cf2e23c7a4a3b3aa8155ac126f1.tgz
INFO:root: + nix-build --argstr pinConfig /home/tim/.config/nix-pin/pins.nix --arg buildPath null --argstr buildPin gnused --arg callArgs {} /nix/store/i94h8xfzwsr83lnwlhv2snbzli0sk8p2-nix-pin-0.3.0/share/nix/call.nix
trace: INFO: <pin:gnused> cf5a401bcbbbf7d6942879fdb7b86108f9c7f77c (~/dev/nix/nix-pin/example/nix-pin-example-sed#default.nix)
building '/nix/store/gzf3rdkwb377bsrypa7p9yhfykywhscb-drv-1.drv'...
Importing from archive: /nix/store/vja9smyk0482kads6pimf2gcfmpl0f5f-gnused-cf5a401bcbbbf7d6942879fdb7b86108f9c7f77c.tgz
these derivations will be built:
  /nix/store/rysf6bzj36a981a7ykr3frp6wcscxj6g-gnused-4.4.drv
building '/nix/store/rysf6bzj36a981a7ykr3frp6wcscxj6g-gnused-4.4.drv'...
# ( ... )
/nix/store/2pacv6jdb3mm9m3zz2ndkz0map4n7j5x-gnused-4.4
```

```
$ ./result/bin/sed --help
Welcome to sed, the stream editor!
Usage: ./result/bin/sed [OPTION]... {script-only-if-no-other-script} [input-file]...
# ( ... )
```

Note that in the output above, the `gnused` pin was updated from `1a2e134fdc3f4cf2e23c7a4a3b3aa8155ac126f1` to `cf5a401bcbbbf7d6942879fdb7b86108f9c7f77c`. The first commit is the head of the `master` branch, but what's the second? We didn't actually commit anything!

```
$ git show cf5a401bcbbbf7d6942879fdb7b86108f9c7f77c
commit cf5a401bcbbbf7d6942879fdb7b86108f9c7f77c
Merge: 1a2e134 246388d
Author: nobody <nobody@example.org>
Date:   Thu Jan 1 00:00:00 1970 +0000

    WIP on master: 1a2e134 add unnecessary output to sed

diff --cc sed/sed.c
index a627381,a627381..5070d9d
--- a/sed/sed.c
+++ b/sed/sed.c
@@@ -229,7 -229,7 +229,7 @@@ main (int argc, char **argv
    int return_code;
    const char *cols = getenv("COLS");
  
--  fprintf(stderr, "Welcome to sed, the streamiest editor!\n");
++  fprintf(stderr, "Welcome to sed, the stream editor!\n");
  
    program_name = argv[0];
    initialize_main (&argc, &argv);
```

`nix-pin` created an anonymous commit (via `git stash create`, which creates a commit but doesn't stash anything), and used that as the current `src`. That way you'll get all your changes to your tracked files, but it still only includes files known to git, so you don't get builds that accidentally rely on files that exist in your workspace but ignored by git.

Thanks for following along, happy pinning!
