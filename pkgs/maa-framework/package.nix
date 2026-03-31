{
  lib,
  stdenv,
  fetchurl,
  callPackage,
  autoPatchelfHook,
  unzip,
  zlib,

  maa-deps ? callPackage ../maa-deps/package.nix {
    version = "2.12.2";
    maaDepsHash = {
      "x86_64-linux" = {
        runtime = "sha256-hbyMULh/jrAq3cdsM38d19En/jrE/9QRxMsuJTGGj8s=";
        devel = "sha256-cdZiaEys/tE3rLP64XNPzJ69flCcWKJ+amotiJ0d0xU=";
        dbg = "sha256-KP+ObYo+PkQ8dEOSzBeJ+7uJXgP12glD+lSLDGPkHzI=";
      };
      "aarch64-linux" = {
        runtime = "sha256-MQUw1dwr68xKPuAK/QxrdLbMlsXvaA8MNzWAXvMzWb8=";
        devel = "sha256-f5syT3gkL58xnkcPyVXnaBmyCjSJ0fLkronUrnQ37KY=";
        dbg = "sha256-4q5jS1LsbkoyjNJK/MN4Kt04GFGqVuYwGlMlWhim83g=";
      };
    };
  },
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
    maa-deps
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
