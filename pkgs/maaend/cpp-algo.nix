{
  pname,
  version,
  src,
  meta,

  callPackage,
  clangStdenv,

  autoPatchelfHook,
  cmake,
  lld,

  boost187,
  fastdeploy_ppocr ? callPackage ../maa-framework/fastdeploy-ppocr.nix { },
  maa-framework,
  onnxruntime,
  opencv,
  zlib,
}:

clangStdenv.mkDerivation (finalAttrs: {
  inherit
    version
    src
    meta
    ;

  pname = "${pname}-cpp-algo";

  sourceRoot = "${src.name}/agent/cpp-algo";

  nativeBuildInputs = [
    autoPatchelfHook
    cmake
    lld
  ];

  env.NIX_CFLAGS_LINK = "-fuse-ld=lld";

  buildInputs = [
    boost187
    fastdeploy_ppocr
    maa-framework
    onnxruntime
    opencv
    zlib
  ];

  patches = [
    ./cpp-algo-path.patch
  ];

  # remove the dependency on MaaDeps, which is replaced by the above buildInputs
  postPatch = ''
    substituteInPlace MaaUtils/MaaUtils.cmake \
      --replace-fail 'include(''${MAADEPS_DIR}/maadeps.cmake)' ""

    substituteInPlace MaaUtils/cmake/utils.cmake \
      --replace-fail 'detect_maadeps_triplet(MAADEPS_TRIPLET)' ""

    substituteInPlace CMakeLists.txt \
      --replace-fail \
      'DEPS_DIR ''${CMAKE_CURRENT_SOURCE_DIR}/../../deps' \
      'DEPS_DIR ${maa-framework}'

    substituteInPlace CMakeLists.txt \
      --replace-fail "RelWithDebInfo" "Release"
  '';

  cmakeFlags = [
    "-DWITH_RPATH_LIBRARY=OFF"
    "-DCMAKE_BUILD_TYPE=Release"
  ];
})
