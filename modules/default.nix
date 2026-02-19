let
  # Recursively walk a directory and collect nix files into an attrset
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
          isNix = typ == "regular" && builtins.match ".+\\.nix$" name != null;
          attrName = builtins.substring 0 (builtins.stringLength name - 4) name;
          recurse = if isDir then mkModules path else { };
        in
        acc // recurse // (if isNix then { ${attrName} = path; } else { });
    in
    builtins.foldl' addEntry { } entries;
in
# export all modules found under this directory (recursive)
mkModules ./.
