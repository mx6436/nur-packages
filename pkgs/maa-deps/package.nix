{
  lib,
  stdenvNoCC,
  fetchurl,
  includeDebug ? false,
  version ? "2.12.1",
  maaDepsHash ? {
    "x86_64-linux" = {
      runtime = "sha256-DRTztnGyiaijgontSXmTBrbcJTn4Ys0zkAIHJ8NJG0k=";
      devel = "sha256-QgBeqbHcXdbw9UZnEJUGVMZBE+XJKQRXMPJTcrxYP+0=";
      dbg = "sha256-XxEC8rx6MEYmcR2wP/wt6F0we5+KNF1nXrnxKovzZ0k=";
    };
    "aarch64-linux" = {
      runtime = "sha256-nzXhyVHyn6taGMAOYDHy4zWIyaO9MUTD1Kf1l3MUQFU=";
      devel = "sha256-srFJ/BMJ2exAKlgq/UgnczlqJVOpUAa9g+PuZlp5dSU=";
      dbg = "sha256-NA4vLKdQwMA6v/OXGUC0d5Dt7xtTlqqV/9CbuwUdi+I=";
    };
  },
}:

let
  system = stdenvNoCC.hostPlatform.system;

  triplet =
    if system == "x86_64-linux" then
      "x64-linux"
    else if system == "aarch64-linux" then
      "arm64-linux"
    else
      throw "Unsupported host platform: ${system}";

  selectedHashes =
    if builtins.hasAttr system maaDepsHash then
      builtins.getAttr system maaDepsHash
    else
      throw "Missing hashes for ${system}";

  baseUrl = "https://github.com/MaaXYZ/MaaDeps/releases/download/v${version}";

  mkAsset =
    kind: hash:
    fetchurl {
      url = "${baseUrl}/MaaDeps-${triplet}-${kind}.tar.xz";
      inherit hash;
    };

  runtimeTar = mkAsset "runtime" selectedHashes.runtime;
  develTar = mkAsset "devel" selectedHashes.devel;
  dbgTar = mkAsset "dbg" selectedHashes.dbg;
in

stdenvNoCC.mkDerivation {
  pname = "maa-deps";
  inherit version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    tar -xJf ${runtimeTar} -C "$out"
    tar -xJf ${develTar} -C "$out"
    ${lib.optionalString includeDebug ''
      tar -xJf ${dbgTar} -C "$out"
    ''}

    runHook postInstall
  '';

  meta = {
    description = "Collection of build scripts to build MAA dependencies for popular platforms";
    homepage = "https://github.com/MaaXYZ/MaaDeps";
    changelog = "https://github.com/MaaXYZ/MaaDeps/releases/tag/v${version}";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
