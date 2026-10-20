{
  cmake,
  config,
  eigen,
  fetchFromGitHub,
  lib,
  onnxruntime,
  opencv,
  stdenv,
  cudaSupport ? config.cudaSupport,
  cudaPackages ? { },
}:

let
  effectiveStdenv = if cudaSupport then cudaPackages.backendStdenv else stdenv;
in
effectiveStdenv.mkDerivation (finalAttrs: {
  pname = "fastdeploy-ppocr";
  version = "0-unstable-2026-09-18";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchFromGitHub {
    owner = "MaaXYZ";
    repo = "FastDeploy";
    # follows https://github.com/MaaXYZ/MaaDeps/blob/master/vcpkg-overlay/ports/maa-fastdeploy/portfile.cmake#L4
    rev = "e11935e4595360e7038573db1a7ab08dd0e096ec";
    hash = "sha256-7g0T5TZ2M2I12nIq9Cytbi8qGw60ssxAgYr2o1pAUVU=";
  };

  postPatch = ''
    # config.h hardcodes WITH_COREML (macOS only) and WITH_DIRECTML (Windows only).
    # onnxruntime nixpkgs ships coreml_provider_factory.h even on Linux, which causes
    # ort_backend.cc to compile CoreML code that references a symbol not exported by onnxruntime.
    sed -i \
      -e '/#define WITH_DIRECTML/d' \
      -e '/#define WITH_COREML/d' \
      fastdeploy/core/config.h
  '';

  nativeBuildInputs = [
    cmake
  ]
  ++ lib.optionals cudaSupport [ cudaPackages.cuda_nvcc ];

  buildInputs = [
    eigen
    onnxruntime
    opencv
  ]
  ++ lib.optionals cudaSupport (
    with cudaPackages;
    [
      cuda_cccl # cub/cub.cuh
      libcublas # cublas_v2.h
      libcurand # curand.h
      libcusparse # cusparse.h
      libcufft # cufft.h
      cudnn # cudnn.h
      cuda_cudart
    ]
  );

  cmakeBuildType = "None";

  cmakeFlags = [
    (lib.cmakeBool "BUILD_SHARED_LIBS" true)
  ]
  ++ lib.optionals cudaSupport [
    (lib.cmakeFeature "CMAKE_CUDA_ARCHITECTURES" cudaPackages.flags.cmakeCudaArchitecturesString)
  ];

  meta = {
    description = "MaaXYZ stripped-down version of FastDeploy";
    homepage = "https://github.com/MaaXYZ/FastDeploy";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    broken = cudaSupport && stdenv.hostPlatform.system != "x86_64-linux";
  };
})
