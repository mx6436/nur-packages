{
  boost187,
  callPackage,
  cmake,
  cppzmq,
  dbus,
  fetchFromGitHub,
  lib,
  libffi,
  libsodium,
  onnxruntime,
  opencv,
  pipewire,
  pkg-config,
  stdenv,
  wayland,
  zlib,
}:

let
  libei = callPackage ./libei.nix { };
  fastdeploy-ppocr = callPackage ./fastdeploy-ppocr.nix { };

  # upstream git submodules, pinned to the commits recorded in MaaFramework
  MaaUtils = fetchFromGitHub {
    owner = "MaaXYZ";
    repo = "MaaUtils";
    rev = "6e9ba33f6ad835418097d9324c01c44a82825a2b";
    hash = "sha256-g6FoqD3EBldHwgULILmxxR9rJajBP5fm6YJynUA8TFY=";
  };

  # runtime agent binaries, installed to $out/share/MaaAgentBinary
  MaaAgentBinary = fetchFromGitHub {
    owner = "MaaXYZ";
    repo = "MaaAgentBinary";
    rev = "173d43c4b5518064b27720b0cf08c781f291eba9";
    hash = "sha256-rj2ZropXC1BwNaMh9NfMxqBEKE5Tx8Eo/x677MglaqI=";
  };
in

stdenv.mkDerivation (finalAttrs: {
  pname = "maa-framework";
  version = "5.14.0";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchFromGitHub {
    owner = "MaaXYZ";
    repo = "MaaFramework";
    tag = "v${finalAttrs.version}";
    sha256 = "sha256-oKYBkLYyXAc4Y+Oiq1PpMxL+PaJ3Z6jv0K88pO7JoZ8=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    boost187 # 1.87.0 is the last version compatible
    cppzmq
    dbus
    fastdeploy-ppocr
    libei
    libffi
    libsodium
    onnxruntime
    opencv
    pipewire
    wayland
    zlib
  ];

  passthru.updateScript = ./update.sh;

  # submodules
  postUnpack = ''
    # contains source/MaaUtils/MaaUtils.cmake
    rm -rf "$sourceRoot/source/MaaUtils"
    cp -r --reflink=auto ${MaaUtils} "$sourceRoot/source/MaaUtils"
    chmod -R u+w "$sourceRoot/source/MaaUtils"

    rm -rf "$sourceRoot/3rdparty/MaaAgentBinary"
    cp -r --reflink=auto ${MaaAgentBinary} "$sourceRoot/3rdparty/MaaAgentBinary"
    chmod -R u+w "$sourceRoot/3rdparty/MaaAgentBinary"
  '';

  postPatch = ''
    # remove the dependency on MaaDeps, which is replaced by the above buildInputs
    substituteInPlace CMakeLists.txt \
      --replace-fail 'maadeps_install(bin)' ""

    substituteInPlace source/MaaUtils/MaaUtils.cmake \
      --replace-fail 'include(''${MAADEPS_DIR}/maadeps.cmake)' ""

    substituteInPlace source/MaaUtils/cmake/utils.cmake \
      --replace-fail "detect_maadeps_triplet(MAADEPS_TRIPLET)" ""

    # Place .so files in $out/lib, not $out/bin
    while IFS= read -r f; do
      substituteInPlace "$f" --replace-fail "LIBRARY DESTINATION bin" "LIBRARY DESTINATION lib"
    done < <(grep -R -l --include='CMakeLists.txt' "LIBRARY DESTINATION bin" .)

    # disable thin LTO
    substituteInPlace source/MaaUtils/cmake/config.cmake \
      --replace-fail '-flto=thin' ""

    substituteInPlace source/MaaUtils/MaaUtils.cmake \
      --replace-fail \
      "OpenCV REQUIRED COMPONENTS core imgproc imgcodecs" \
      "OpenCV REQUIRED COMPONENTS core imgproc imgcodecs features2d calib3d flann"

    # gcc 在 -Wpedantic 下无法编译 PipeWire/SPA 头文件里的 GNU 复合字面量
    substituteInPlace source/MaaUtils/cmake/config.cmake \
      --replace-fail '"-Wall;-Werror;-Wextra;-Wpedantic;-Wno-missing-field-initializers"' \
      '"-Wall;-Werror;-Wextra;-Wno-missing-field-initializers"'
  '';

  # make empty dir to suppress warnings
  # TODO: add a wrapper for plugins
  postInstall = ''
    mkdir -p $out/lib/plugins
  '';

  cmakeFlags = [
    (lib.cmakeFeature "MAA_HASH_VERSION" finalAttrs.version)
    (lib.cmakeBool "WITH_RPATH_LIBRARY" false)
    (lib.cmakeBool "BUILD_PICLI" false)
  ];

  meta = {
    description = "An automation black-box testing framework based on image recognition";
    homepage = "https://maafw.com";
    changelog = "https://github.com/MaaXYZ/MaaFramework/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.lgpl3Only;
    platforms = lib.platforms.linux;
  };
})
