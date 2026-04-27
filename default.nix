# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage

{
  pkgs ? import <nixpkgs> { },
}:

let
  # path to the packages directory relative to this file
  pkgRoot = ./pkgs;

  # list of subdirectories in pkgs that contain a package.nix
  pkgNames = builtins.filter (name: builtins.pathExists (./pkgs/${name}/package.nix)) (
    builtins.attrNames (builtins.readDir pkgRoot)
  );

  # Build all packages in a shared scope so package-level dependencies
  # can be resolved from other packages in this repository.
  packageScope = pkgs.lib.makeScope pkgs.newScope (
    self:
    builtins.listToAttrs (
      map (name: {
        name = name;
        value = self.callPackage (./pkgs/${name}/package.nix) { };
      }) pkgNames
    )
  );
in

{
  # The `lib`, `modules`, and `overlays` names are special
  lib = import ./lib { inherit pkgs; }; # functions
  modules = import ./modules; # NixOS modules
  overlays = import ./overlays; # nixpkgs overlays
}

# merge in dynamically-discovered packages
// packageScope
