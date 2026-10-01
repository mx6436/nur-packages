{
  android-tools,
  callPackage,
  copyDesktopItems,
  fetchFromGitHub,
  lib,
  libayatana-appindicator,
  maa-framework,
  makeDesktopItem,
  mxu-unwrapped,
  nssTools,
  stdenvNoCC,
  wrapGAppsHook3,
}:

let
  pname = "maaend";
  version = "2.31.0-beta.6";

  src = fetchFromGitHub {
    owner = "MaaEnd";
    repo = "MaaEnd";
    tag = "v${version}";
    hash = "sha256-eqe18gL4+CQNYxZDGJGnHttyVjAVpZNTNdOHHLk0w+Q=";
  };

  # agent/cpp-algo/MaaUtils submodule
  maaUtils = fetchFromGitHub {
    owner = "MaaXYZ";
    repo = "MaaUtils";
    rev = "6e9ba33f6ad835418097d9324c01c44a82825a2b";
    hash = "sha256-g6FoqD3EBldHwgULILmxxR9rJajBP5fm6YJynUA8TFY=";
  };

  # assets/resource/model submodule
  maaendAI = fetchFromGitHub {
    owner = "MaaEnd";
    repo = "MaaEnd-AI";
    rev = "3178323b321a5853a929dd3c4b98896ec0eb4f45";
    hash = "sha256-syNCvK+4UDUC8PZY+uym0fFX5dmI8UrLx0B5Vn8NFEk=";
  };

  go-service = callPackage ./go-service.nix {
    inherit
      pname
      version
      src
      meta
      ;
  };

  cpp-algo = callPackage ./cpp-algo.nix {
    inherit
      pname
      version
      src
      maaUtils
      meta
      ;
  };

  runtimeTools = [
    android-tools
    nssTools
  ];

  meta = {
    description = "MAA Helper for Arknights: Endfield";
    homepage = "https://maaend.com";
    changelog = "https://github.com/MaaEnd/MaaEnd/releases/tag/v${version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "MaaEnd";
    platforms = lib.platforms.linux;
  };
in

stdenvNoCC.mkDerivation (finalAttrs: {
  inherit
    pname
    version
    src
    meta
    ;

  __structuredAttrs = true;
  strictDeps = true;

  passthru.updateScript = ./update.fish;

  nativeBuildInputs = [
    copyDesktopItems
    wrapGAppsHook3
  ];

  postPatch = ''
    # write version to interface.json
    substituteInPlace assets/interface.json \
      --replace-fail '"version": "v0.1.0"' '"version": "v${finalAttrs.version}"'
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/{maafw,agent} $out/share/icons/hicolor/512x512/apps

    # MXU hardcodes MAA library path to $exe_dir/maafw
    cp -r ${maa-framework}/lib/. $out/lib/maafw
    cp -r ${maa-framework}/share/MaaAgentBinary $out/lib/maafw/MaaAgentBinary

    cp ${mxu-unwrapped}/bin/mxu $out/lib/mxu
    ln -s $out/lib/mxu $out/bin/MaaEnd  # This symlink will be wrapped by wrapGAppsHook3

    cp ${go-service}/bin/go-service $out/lib/agent/go-service
    cp ${cpp-algo}/agent/cpp-algo $out/lib/agent/cpp-algo
    cp -r assets/. $out/lib

    # assets/resource/model submodule
    rm -rf $out/lib/resource/model
    ln -s ${maaendAI} $out/lib/resource/model

    cp README.md $out/lib/README.md
    cp LICENSE $out/lib/LICENSE
    cp $out/lib/locales/MaaEnd-Tiny.png $out/share/icons/hicolor/512x512/apps/MaaEnd-Tiny.png

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libayatana-appindicator ]}
      --prefix PATH : ${lib.makeBinPath runtimeTools}
    )

    substituteInPlace $out/share/applications/maaend.desktop \
      --replace-fail "Exec=MaaEnd" "Exec=$out/bin/MaaEnd"
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "maaend";
      type = "Application";
      desktopName = "MaaEnd";
      comment = "MAA Helper for Arknights: Endfield";
      icon = "MaaEnd-Tiny";
      startupWMClass = "MaaEnd";
      exec = "MaaEnd";
      categories = [ "Utility" ];
    })
  ];
})
