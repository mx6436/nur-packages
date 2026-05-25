{
  boost187,
  callPackage,
  cmake,
  cppzmq,
  fetchFromGitHub,
  lib,
  libffi,
  libsodium,
  onnxruntime,
  opencv,
  stdenv,
  wayland,
  zlib,

  withCli ? false,
}:

let
  fastdeploy-ppocr = callPackage ./fastdeploy-ppocr.nix { };
in

stdenv.mkDerivation (finalAttrs: {
  pname = "maa-framework";
  version = "5.10.5";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchFromGitHub {
    owner = "MaaXYZ";
    repo = "MaaFramework";
    rev = "v${finalAttrs.version}";
    fetchSubmodules = true;
    sha256 = "sha256-/XglJ4kXpLYeBFODp4BmFrsoa934MueGR09/UUaOJmc=";
  };

  nativeBuildInputs = [
    cmake
  ];

  buildInputs = [
    boost187 # 1.87.0 is the last version compatible
    cppzmq
    fastdeploy-ppocr
    libffi
    libsodium
    onnxruntime
    opencv
    wayland.dev
    zlib
  ];

  patches = [
    ./handle-EINTR.patch
  ]
  ++ lib.optionals withCli [
    ./picli-path-resolution.patch
  ];

  postPatch = ''
    # remove the dependency on MaaDeps, which is replaced by the above buildInputs
    substituteInPlace CMakeLists.txt \
      --replace-fail 'maadeps_install(bin)' ""

    substituteInPlace source/MaaUtils/MaaUtils.cmake \
      --replace-fail 'include(''${MAADEPS_DIR}/maadeps.cmake)' "" \
      --replace-fail \
      "OpenCV REQUIRED COMPONENTS core imgproc imgcodecs" \
      "OpenCV REQUIRED COMPONENTS core imgproc imgcodecs features2d calib3d flann"

    substituteInPlace source/MaaUtils/cmake/utils.cmake \
      --replace-fail "detect_maadeps_triplet(MAADEPS_TRIPLET)" ""

    # Place .so files in $out/lib, not $out/bin
    while IFS= read -r f; do
      substituteInPlace "$f" --replace-fail "LIBRARY DESTINATION bin" "LIBRARY DESTINATION lib"
    done < <(grep -R -l --include='CMakeLists.txt' "LIBRARY DESTINATION bin" .)

    # disable thin LTO
    substituteInPlace source/MaaUtils/cmake/config.cmake \
      --replace-fail '-flto=thin' ""

    # fix -Werror=format
    substituteInPlace source/MaaToolkit/DesktopWindow/DesktopWindowLinuxFinder.cpp \
      --replace-fail "wayland-%d" "wayland-%u"
  '';

  # make empty dir to suppress warnings
  # TODO: add a wrapper for plugins
  postInstall = ''
    mkdir -p $out/lib/plugins
  '';

  cmakeFlags = [
    (lib.cmakeBool "WITH_RPATH_LIBRARY" false)
    (lib.cmakeFeature "MAA_HASH_VERSION" finalAttrs.version)
  ]
  ++ lib.optionals (!withCli) [
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
