{
  pname,
  version,
  src,
  meta,

  boost187,
  cmake,
  lib,
  maa-framework,
  onnxruntime,
  opencv,
  stdenv,
  zlib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "${pname}-cpp-algo";
  inherit
    version
    src
    meta
    ;

  __structuredAttrs = true;
  strictDeps = true;

  cmakeDir = "../agent/cpp-algo";

  nativeBuildInputs = [
    cmake
  ];

  buildInputs = [
    boost187
    maa-framework
    onnxruntime
    opencv
    zlib
  ];

  patches = [
    ./0001-cpp-data-dir.patch
  ];

  postPatch = ''
    # Build against Nix-provided dependencies instead of MaaDeps.
    substituteInPlace agent/cpp-algo/MaaUtils/MaaUtils.cmake \
      --replace-fail 'include(''${MAADEPS_DIR}/maadeps.cmake)' "" \
      --replace-fail "find_package(fastdeploy_ppocr REQUIRED)" ""
    substituteInPlace agent/cpp-algo/MaaUtils/cmake/utils.cmake \
      --replace-fail 'detect_maadeps_triplet(MAADEPS_TRIPLET)' ""

    # Resolve framework paths from the packaged maa-framework output.
    substituteInPlace agent/cpp-algo/CMakeLists.txt \
      --replace-fail 'DEPS_DIR ''${CMAKE_CURRENT_SOURCE_DIR}/../../deps' 'DEPS_DIR ${maa-framework}' \
      --replace-fail "RelWithDebInfo" "Release"

    # MaaUtils is provided by maa-framework, not this build tree.
    substituteInPlace agent/cpp-algo/source/CMakeLists.txt \
      --replace-fail "add_dependencies(cpp-algo MaaUtils)" ""
  '';

  cmakeFlags = [
    (lib.cmakeBool "BUILD_MAA_UTILS" false)
    (lib.cmakeBool "WITH_RPATH_LIBRARY" false)
  ];
})
