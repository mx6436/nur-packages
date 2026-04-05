{
  lib,
  callPackage,
  fetchFromGitHub,
  stdenvNoCC,

  wrapGAppsHook3,
  glib-networking,
  libayatana-appindicator,
  libsoup_3,
  openssl,
  webkitgtk_4_1,

  maa-framework ? callPackage ../maa-framework/package.nix { },
  mxu ? callPackage ../mxu/package.nix { },

  android-tools,
}:

let
  pname = "maaend";
  version = "2.4.0";

  src = fetchFromGitHub {
    owner = "MaaEnd";
    repo = "MaaEnd";
    rev = "v${version}";
    hash = "sha256-VRFRzJioNc/HJFWh1r3EBSndPv5kJs77lsDGxpnREGU=";
    fetchSubmodules = true;
  };

  vendorHash = "sha256-0R2PNroT0WpVOtQcT2N+6wP9zcInrV/31Dsv+o8sQB8=";

  go-service = callPackage ./go-service.nix {
    inherit
      pname
      version
      src
      meta
      vendorHash
      ;
  };

  cpp-algo = callPackage ./cpp-algo.nix {
    inherit
      pname
      version
      src
      meta
      maa-framework
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

  nativeBuildInputs = [
    wrapGAppsHook3
  ];

  buildInputs = [
    glib-networking
    libayatana-appindicator
    libsoup_3
    openssl
    webkitgtk_4_1
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/{agent,maafw}
    mkdir -p $out/bin

    # This can't be symbol linked. It will find resource in its runtime path.
    # `mxu` is a wrapper script, copying it is no use. We need to copy the wrapped binary and wrap it again.
    cp ${mxu}/bin/.mxu-wrapped $out/lib/.mxu-wrapped

    # This will be wrapped by wrapGAppsHook3
    ln -s $out/lib/.mxu-wrapped $out/bin/MaaEnd

    cp ${go-service}/bin/go-service $out/lib/agent/go-service
    cp ${cpp-algo}/agent/cpp-algo $out/lib/agent/cpp-algo

    # cp ${maa-framework}/bin/MaaPiCli $out/lib/maafw/
    ln -s ${maa-framework}/lib/* $out/lib/maafw
    ln -s ${maa-framework}/share/MaaAgentBinary $out/lib/maafw/MaaAgentBinary

    cp -r $src/assets/* $out/lib/
    cp $src/README.md $out/lib/
    cp $src/LICENSE $out/lib/

    # write version to interface.json
    substituteInPlace $out/lib/interface.json --replace-fail \
      "0.1.0" "${finalAttrs.version}"

    # Desktop entry
    mkdir -p $out/share/applications
    cat > $out/share/applications/maaend.desktop <<EOF
    [Desktop Entry]
    Name=MaaEnd
    Comment=MAA Helper for Arknights: Endfield
    Exec=$out/bin/MaaEnd %U
    Icon=MaaEnd-Tiny
    Terminal=false
    Type=Application
    Categories=Utility;
    EOF

    mkdir -p $out/share/icons/hicolor/512x512/apps
    ln -s $out/lib/locales/MaaEnd-Tiny.png $out/share/icons/hicolor/512x512/apps/MaaEnd-Tiny.png

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libayatana-appindicator ]}
      --prefix PATH : ${lib.makeBinPath [ android-tools ]}
    )
  '';
})
