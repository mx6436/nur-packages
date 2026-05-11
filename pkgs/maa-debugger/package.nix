{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildGoModule,
  makeWrapper,
  nodejs,
  pnpm_10,
  pnpmConfigHook,
  maa-framework,
}:

let
  pname = "maa-debugger";
  version = "unstable-2026-04-24";

  src = fetchFromGitHub {
    owner = "MaaXYZ";
    repo = "MaaDebugger";
    rev = "10ee13d2c98964ee2c9605e5596335676bfe4b6e";
    hash = "sha256-MQpyic7pNx4Rktc7ugMKqDNES6IrvZ9fAeuMZYURyGQ=";
  };

  vendorHash = "sha256-8fg5Yg7gy28V4nj+Qu3ZuvMX/qtbxoNXXfxPYSWlypY=";

  frontend = stdenvNoCC.mkDerivation {
    pname = "${pname}-frontend";
    inherit version src;

    __structuredAttrs = true;

    pnpmDeps = fetchPnpmDeps {
      inherit pname version src;
      fetcherVersion = 3;
      pnpm = pnpm_10;
      hash = "sha256-QWswAlGvEgPtNeCwhiGZ2YIrn1TMWQi40nt8QV5IXiQ=";
      sourceRoot = "${src.name}/web";
    };

    pnpmRoot = "web";

    nativeBuildInputs = [
      nodejs
      pnpm_10
      pnpmConfigHook
    ];

    buildPhase = ''
      (cd web && pnpm run build)
    '';

    installPhase = ''
      mkdir -p $out
      mv server/frontend/dist $out/dist
    '';
  };
in

buildGoModule (finalAttrs: {
  inherit
    pname
    version
    src
    vendorHash
    ;

  __structuredAttrs = true;

  modRoot = "server";
  subPackages = [ "cmd/server" ];

  ldflags = [
    "-X github.com/MaaXYZ/MaaDebugger/internal/buildinfo.Version=${version}"
    "-X github.com/MaaXYZ/MaaDebugger/internal/buildinfo.CommitSHA=${src.rev}"
  ];

  nativeBuildInputs = [
    makeWrapper
  ];

  preConfigure = ''
    mkdir -p server/frontend/dist
    cp -r ${frontend}/dist/* server/frontend/dist/
  '';

  postInstall = ''
    mv $out/bin/server $out/bin/MaaDebugger

    mkdir -p $out/lib/maafw
    ln -s ${maa-framework}/lib/* $out/lib/maafw
    ln -s ${maa-framework}/share/MaaAgentBinary $out/lib/maafw/MaaAgentBinary

    wrapProgram $out/bin/MaaDebugger \
      --set-default MAAFW_BINARY_PATH $out/lib/maafw
  '';

  meta = {
    description = "Official desktop debugger for MaaFramework, featuring a web-based UI and real-time task inspection.";
    homepage = "https://github.com/MaaXYZ/MaaDebugger/tree/rft/nodejs";
    license = lib.licenses.mit;
    mainProgram = "MaaDebugger";
    platforms = lib.platforms.linux;
  };
})
