let
  moduleNames = builtins.filter (
    name: builtins.match ".*\\.nix$" name != null && name != "default.nix"
  ) (builtins.attrNames (builtins.readDir ./.));
in

builtins.listToAttrs (
  map (name: {
    name = builtins.head (builtins.match "(.*)\\.nix$" name);
    value = import ./${name};
  }) moduleNames
)
