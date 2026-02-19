{
  lib,
  stdenvNoCC,
  fetchzip,
  zstd,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "natfrp-service";
  version = "3.1.7";

  src = fetchzip {
    url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${finalAttrs.version}/natfrp-service_linux_amd64.tar.zst";
    hash = "sha256-qAEyYdi81nj+TrxTNC8dPUpmnJaACBldeKZjU7QvYFg=";
    nativeBuildInputs = [ zstd ];
    stripRoot = false;
  };

  installPhase = ''
    runHook preInstall

    install -Dm755 frpc $out/bin/frpc
    install -Dm755 natfrp-service $out/bin/natfrp-service

    runHook postInstall
  '';

  dontPatchELF = true; # statically linked
  dontStrip = true; # no section header

  meta = {
    description = "Sakura Frp Launcher.";
    homepage = "https://www.natfrp.com";
    license = lib.licenses.unfree;
    maintainers = [ ];
    mainProgram = "natfrp-service";
    platforms = [ "x86_64-linux" ];
  };
})
