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
  version = "2.19.0";
  srcHash = "sha256-Zp4jpME5fIr0bvc08UEXACvMYzTsAVcXl+n4JDj5/FU=";
  vendorHash = "sha256-pgL/rP28YN0q49yPyBN3DTvwn/xdcKF1BE74gBuyyrU=";

  # submodule revisions/hashes, fetched separately instead of with fetchSubmodules
  maaUtilsRev = "f53406a6146d4c9fd4bcbaffcfd9e70865676903";
  maaUtilsHash = "sha256-EfcQbQj5yz/wFQwjdv23Pj4io/aS5e7b8e6l4oclZUQ=";
  maaendAiRev = "563373e0ce58f2bac5e07625618a2f83e442cf30";
  maaendAiHash = "sha256-4Hi6vqhuTdJ4Q1p0iQIOedd/ZxUKOKNElTsDgZpBRxw=";

  src = fetchFromGitHub {
    owner = "MaaEnd";
    repo = "MaaEnd";
    tag = "v${version}";
    hash = srcHash;
  };

  # agent/cpp-algo/MaaUtils
  maaUtils = fetchFromGitHub {
    owner = "MaaXYZ";
    repo = "MaaUtils";
    rev = maaUtilsRev;
    hash = maaUtilsHash;
  };

  # assets/resource/model
  maaendAi = fetchFromGitHub {
    owner = "MaaEnd";
    repo = "MaaEnd-AI";
    rev = maaendAiRev;
    hash = maaendAiHash;
  };

  go-service = callPackage ./go-service.nix {
    inherit
      pname
      version
      src
      vendorHash
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
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "maaend";
      type = "Application";
      desktopName = "MaaEnd";
      comment = "MAA Helper for Arknights: Endfield";
      icon = "MaaEnd-Tiny";
      exec = "MaaEnd";
      categories = [ "Utility" ];
    })
  ];
})
