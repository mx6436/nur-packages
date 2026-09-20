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
  stdenvNoCC,
  wrapGAppsHook3,
}:

let
  pname = "maaend";
  version = "2.30.0-beta.1";

  src = fetchFromGitHub {
    owner = "MaaEnd";
    repo = "MaaEnd";
    tag = "v${version}";
    hash = "sha256-+WAQeSKpjxWxH7krsaOuQhkZWbN19GGZ12es8Th1fro=";
  };

  # submodules are fetched as separate tarballs instead of with fetchSubmodules

  # agent/cpp-algo/MaaUtils
  maaUtils = fetchFromGitHub {
    owner = "MaaXYZ";
    repo = "MaaUtils";
    rev = "6e9ba33f6ad835418097d9324c01c44a82825a2b";
    hash = "sha256-g6FoqD3EBldHwgULILmxxR9rJajBP5fm6YJynUA8TFY=";
  };

  # assets/resource/model
  maaendAi = fetchFromGitHub {
    owner = "MaaEnd";
    repo = "MaaEnd-AI";
    rev = "e2f1e9e2067312f82ef630da3ba5515fdf55fd6c";
    hash = "sha256-4tAgreM4cf1wdLlwVF37Ki1kVFYlUbNAZgMfIWZ+maA=";
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
      --replace-fail "0.1.0" "${finalAttrs.version}"
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/{maafw,agent} $out/share/icons/hicolor/512x512/apps

    # MXU hardcodes MAA library path to $exe_dir/maafw
    cp -r ${maa-framework}/lib/. $out/lib/maafw
    cp -r ${maa-framework}/share/MaaAgentBinary $out/lib/maafw/MaaAgentBinary

    cp ${mxu-unwrapped}/bin/mxu $out/lib/mxu
    # This symlink will be wrapped by wrapGAppsHook3
    ln -s $out/lib/mxu $out/bin/MaaEnd

    cp ${go-service}/bin/go-service $out/lib/agent/go-service
    cp ${cpp-algo}/agent/cpp-algo $out/lib/agent/cpp-algo
    cp -r assets/. $out/lib
    rm -rf $out/lib/resource/model
    # assets/resource/model
    ln -s ${maaendAi} $out/lib/resource/model

    cp README.md $out/lib/README.md
    cp LICENSE $out/lib/LICENSE
    cp $out/lib/locales/MaaEnd-Tiny.png $out/share/icons/hicolor/512x512/apps/MaaEnd-Tiny.png

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libayatana-appindicator ]}
      --prefix PATH : ${lib.makeBinPath [ android-tools ]}
    )

    # makeDesktopItem 引用不到本包的 $out，这里补成绝对路径。
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
      # 实际 WM_CLASS 是 MaaEnd，与文件名大小写不一致。
      startupWMClass = "MaaEnd";
      exec = "MaaEnd";
      categories = [ "Utility" ];
    })
  ];
})
