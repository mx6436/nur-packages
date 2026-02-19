{
  lib,
  stdenv,
  callPackage,
  wrapGAppsHook3,
  glib-networking,
  desktop-file-utils,

  addDriverRunpath,
  alsa-lib,
  flite,
  gamemode,
  glfw3-minecraft,
  jdk17,
  jdk21,
  jdk25,
  jdk8,
  libGL,
  libjack2,
  libpulseaudio,
  libusb1,
  libx11,
  libxcursor,
  libxext,
  libxrandr,
  libxxf86vm,
  mesa-demos,
  openal,
  pciutils,
  pipewire,
  udev,
  vulkan-loader,
  xrandr,

  additionalLibs ? [ ],
  additionalPrograms ? [ ],
  jdks ? [
    jdk25
    jdk21
    jdk17
    jdk8
  ],
  controllerSupport ? stdenv.hostPlatform.isLinux,
  gamemodeSupport ? stdenv.hostPlatform.isLinux,
  textToSpeechSupport ? stdenv.hostPlatform.isLinux,
}:

assert lib.assertMsg (
  controllerSupport -> stdenv.hostPlatform.isLinux
) "controllerSupport only has an effect on Linux.";

assert lib.assertMsg (
  textToSpeechSupport -> stdenv.hostPlatform.isLinux
) "textToSpeechSupport only has an effect on Linux.";

let

  unwrapped = callPackage ./unwrapped.nix { };

  runtimeLibs = [
    (lib.getLib stdenv.cc.cc)
    ## native versions
    glfw3-minecraft
    openal

    ## openal
    alsa-lib
    libjack2
    libpulseaudio
    pipewire

    ## glfw
    libGL
    libx11
    libxcursor
    libxext
    libxrandr
    libxxf86vm

    udev # oshi

    vulkan-loader # VulkanMod's lwjgl
  ]
  ++ lib.optional textToSpeechSupport flite
  ++ lib.optional gamemodeSupport gamemode.lib
  ++ lib.optional controllerSupport libusb1
  ++ additionalLibs;

  runtimePrograms = [
    mesa-demos
    pciutils # need lspci
    xrandr # needed for LWJGL [2.9.2, 3) https://github.com/LWJGL/lwjgl/issues/128
  ]
  ++ lib.optional stdenv.hostPlatform.isLinux desktop-file-utils # Tauri Deep Linking
  ++ additionalPrograms;

in

stdenv.mkDerivation {
  pname = "sjmcl";
  inherit (unwrapped) version;

  dontUnpack = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    wrapGAppsHook3
  ];

  BuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    glib-networking
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib,share}
    ln -s ${unwrapped}/bin/* $out/bin/
    ln -s ${unwrapped}/lib/* $out/lib/
    ln -s ${unwrapped}/share/* $out/share/

    runHook postInstall
  '';

  preFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${addDriverRunpath.driverLink}/lib
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}
      --prefix PATH : ${lib.makeBinPath runtimePrograms}
      --prefix PATH : ${lib.makeBinPath jdks}
    )
  '';

  meta = {
    inherit (unwrapped.meta)
      description
      homepage
      changelog
      license
      maintainers
      mainProgram
      platforms
      ;
  };
}
