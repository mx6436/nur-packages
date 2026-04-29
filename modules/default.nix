let
  overlay = import ../overlays/default.nix;

  mkModules =
    dir:
    let
      entriesWithType = builtins.readDir dir;
      entries = builtins.attrNames entriesWithType;
      addEntry =
        acc: name:
        let
          path = builtins.toString dir + "/" + name;
          typ = entriesWithType.${name};
          isDir = typ == "directory";
          isNix = typ == "regular" && builtins.match ".+\\.nix$" name != null && name != "default.nix";
          attrName = builtins.substring 0 (builtins.stringLength name - 4) name;
          recurse = if isDir then mkModules path else { };
        in
        acc
        // recurse
        // (
          if isNix then
            {
              ${attrName} = {
                imports = [
                  {
                    nixpkgs.overlays = [ overlay ];
                  }
                  path
                ];
              };
            }
          else
            { }
        );
    in
    builtins.foldl' addEntry { } entries;
in
mkModules ./.
