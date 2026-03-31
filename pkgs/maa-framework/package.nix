{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  unzip,
  zlib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "maa-framework";
  version = "5.9.2";

  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    unzip
  ];

  buildInputs = [
    zlib
  ];

  src = fetchurl {
    url = "https://github.com/MaaXYZ/MaaFramework/releases/download/v${finalAttrs.version}/MAA-linux-${
      {
        x86_64-linux = "x86_64";
        aarch64-linux = "aarch64";
      }
      .${stdenv.hostPlatform.system}
    }-v${finalAttrs.version}.zip";
    hash =
      {
        x86_64-linux = "sha256-Tox4eBULt06zZPikY/xPFWd54QR/XVKbSyvNgvssRdI=";
        aarch64-linux = "sha256-g4XUmYS93mqSDMNvEoGMclSR7qUp2lJojKFZHP6nLXM=";
      }
      .${stdenv.hostPlatform.system};
  };

  installPhase = ''
    runHook preInstall

    unzip -q "$src" -d "$out"

    runHook postInstall
  '';

  meta = {
    description = "An automation black-box testing framework based on image recognition";
    homepage = "https://maafw.com";
    changelog = "https://github.com/MaaXYZ/MaaFramework/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.lgpl3Only;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
