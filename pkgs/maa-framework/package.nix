{
  lib,
  callPackage,
  clangStdenv,
  fetchFromGitHub,

  autoPatchelfHook,
  cmake,
  lld,

  boost187,
  cppzmq,
  fastdeploy-ppocr ? callPackage ./fastdeploy-ppocr.nix { },
  libffi,
  opencv,
  onnxruntime,
  wayland,
  zlib,

  withCli ? false,
}:

clangStdenv.mkDerivation (finalAttrs: {
  pname = "maa-framework";
  version = "5.10.2";

  src = fetchFromGitHub {
    owner = "MaaXYZ";
    repo = "MaaFramework";
    rev = "v${finalAttrs.version}";
    fetchSubmodules = true;
    sha256 = "sha256-RGCr4gzbQ8wqVE/KNMkdr8AYNxidZEPJ6wexfJ7iax4=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    cmake
    lld
  ];

  env.NIX_CFLAGS_LINK = "-fuse-ld=lld";

  buildInputs = [
    boost187 # 1.87.0 is the last version compatible
    cppzmq
    fastdeploy-ppocr
    libffi
    opencv
    onnxruntime
    wayland.dev
    zlib
  ];

  patches = lib.optionals withCli [
    ./picli-path-resolution.patch
  ];

  # remove the dependency on MaaDeps, which is replaced by the above buildInputs
  postPatch = ''
    substituteInPlace source/MaaUtils/MaaUtils.cmake --replace-fail \
      'include(''${MAADEPS_DIR}/maadeps.cmake)' ""

    substituteInPlace source/MaaUtils/cmake/utils.cmake --replace-fail \
      'detect_maadeps_triplet(MAADEPS_TRIPLET)' ""

    substituteInPlace CMakeLists.txt --replace-fail \
      'maadeps_install(bin)' ""

    substituteInPlace source/MaaUtils/MaaUtils.cmake --replace-fail \
      "OpenCV REQUIRED COMPONENTS core imgproc imgcodecs" \
      "OpenCV REQUIRED COMPONENTS core imgproc imgcodecs features2d calib3d flann"

    while IFS= read -r f; do
      substituteInPlace "$f" --replace-fail "LIBRARY DESTINATION bin" "LIBRARY DESTINATION lib"
    done < <(grep -R -l --include='CMakeLists.txt' "LIBRARY DESTINATION bin" .)
  '';

  # TODO: add a wrapper for plugins
  postInstall = ''
    mkdir -p $out/lib/plugins
  '';

  # $out/share/MaaAgentBinary do not need to be patched
  dontAutoPatchelf = true;
  postFixup = ''
    autoPatchelf $out/bin $out/lib
  '';

  cmakeFlags = [
    "-DWITH_RPATH_LIBRARY=OFF"
    "-DMAA_HASH_VERSION=${finalAttrs.version}"
    "-DWITH_WIN32_CONTROLLER=OFF"
    "-DWITH_PLAYCOVER_CONTROLLER=OFF"
    "-DWITH_ANDROID_NATIVE_CONTROLLER=OFF"
    "-DWITH_GAMEPAD_CONTROLLER=OFF" # supports only windows
  ]
  ++ lib.optional (!withCli) "-DBUILD_PICLI=OFF";

  meta = {
    description = "An automation black-box testing framework based on image recognition";
    homepage = "https://maafw.com";
    changelog = "https://github.com/MaaXYZ/MaaFramework/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.lgpl3Only;
    platforms = lib.platforms.linux;
  };
})
