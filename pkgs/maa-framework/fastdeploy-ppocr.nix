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
  version = "0-unstable-2025-08-12";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchFromGitHub {
    owner = "MaaXYZ";
    repo = "FastDeploy";
    # follows https://github.com/MaaXYZ/MaaDeps/blob/master/vcpkg-overlay/ports/maa-fastdeploy/portfile.cmake#L4
    rev = "e962983da6daba7d0c12f6bf5f8ff7173be70982";
    hash = "sha256-T20WhXE1toEgeXbMlQn9EnLXoz5vepUca4p7C2tQK44=";
  };

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
