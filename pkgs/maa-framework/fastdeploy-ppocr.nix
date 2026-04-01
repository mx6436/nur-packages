################################################################################
# Mostly based on fastdeploy_ppocr.nix from maa-assistant-arknights on nixpkgs
################################################################################

{
  stdenv,
  config,
  lib,
  fetchFromGitHub,
  cmake,
  eigen,
  onnxruntime,
  opencv,
  cudaSupport ? config.cudaSupport,
  cudaPackages ? { },
}@inputs:

let
  effectiveStdenv = if cudaSupport then cudaPackages.backendStdenv else inputs.stdenv;
in
effectiveStdenv.mkDerivation (finalAttrs: {
  pname = "fastdeploy-ppocr";
  version = "e962983";

  src = fetchFromGitHub {
    owner = "MaaXYZ";
    repo = "FastDeploy";
    # follows https://github.com/MaaXYZ/MaaDeps/blob/master/vcpkg-overlay/ports/maa-fastdeploy/portfile.cmake#L4
    rev = "e962983da6daba7d0c12f6bf5f8ff7173be70982";
    hash = "sha256-T20WhXE1toEgeXbMlQn9EnLXoz5vepUca4p7C2tQK44=";
  };

  nativeBuildInputs = [
    cmake
    eigen
  ]
  ++ lib.optionals cudaSupport [ cudaPackages.cuda_nvcc ];

  buildInputs = [
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
