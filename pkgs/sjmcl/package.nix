{
  lib,
  stdenv,
  makeWrapper,
  sjmcl-unwrapped,
  symlinkJoin,

  addDriverRunpath,
  alsa-lib,
  desktop-file-utils,
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
    desktop-file-utils # Tauri Deep Linking
    mesa-demos
    pciutils # need lspci
    xrandr # needed for LWJGL [2.9.2, 3) https://github.com/LWJGL/lwjgl/issues/128
  ]
  ++ additionalPrograms;

in

symlinkJoin {
  pname = "sjmcl";
  inherit (sjmcl-unwrapped) version;

  paths = [ sjmcl-unwrapped ];

  nativeBuildInputs = [
    makeWrapper
  ];

  postBuild = ''
    wrapProgram $out/bin/SJMCL \
      --set APPIMAGE "$out/bin/SJMCL" \
      --prefix LD_LIBRARY_PATH : ${addDriverRunpath.driverLink}/lib \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs} \
      --prefix PATH : ${lib.makeBinPath runtimePrograms} \
      --prefix PATH : ${lib.makeBinPath jdks}
  '';

  meta = {
    inherit (sjmcl-unwrapped.meta)
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
