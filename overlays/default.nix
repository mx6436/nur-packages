final: prev:

let
  pkgRoot = ../pkgs;

  pkgNames = builtins.filter (name: builtins.pathExists (../pkgs/${name}/package.nix)) (
    builtins.attrNames (builtins.readDir pkgRoot)
  );
in

prev.lib.makeScope prev.newScope (
  self:
  builtins.listToAttrs (
    map (name: {
      name = name;
      value = self.callPackage (../pkgs/${name}/package.nix) { };
    }) pkgNames
  )
  // {
    maaend-beta = self.callPackage ../pkgs/maaend/package.nix { isBeta = true; };
  }
)
