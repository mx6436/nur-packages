{
  callPackage,
  lib,
  libayatana-appindicator,
  mxu-unwrapped ? callPackage ../mxu-unwrapped/package.nix { },
  symlinkJoin,
  wrapGAppsHook3,
}:

let
  mxu' = mxu-unwrapped;
in

symlinkJoin {
  pname = "mxu";
  inherit (mxu') version;

  paths = [ mxu' ];

  nativeBuildInputs = [ wrapGAppsHook3 ];

  postBuild = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libayatana-appindicator ]}
    )
    wrapGAppsHook
  '';

  meta = {
    inherit (mxu'.meta)
      description
      homepage
      changelog
      license
      mainProgram
      platforms
      ;
  };
}
