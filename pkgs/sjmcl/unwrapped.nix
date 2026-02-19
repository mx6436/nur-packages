{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  fetchNpmDeps,
  cargo-tauri,
  nodejs,
  npmHooks,
  openssl,
  pkg-config,
  webkitgtk_4_1,
  libsoup_3,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "sjmcl-unwrapped";
  version = "0.8.2";

  src = fetchFromGitHub {
    owner = "UNIkeEN";
    repo = "SJMCL";
    rev = "v${finalAttrs.version}";
    hash = "sha256-9F6AaCKmxKHJdXy7KyAat3LgEpXWfmKuHL2kNAdlgkE=";
  };

  cargoHash = "sha256-ko6MQoCNRxSDMJZUG4tTbZIGO/PvkZE6JF51rKpnKzI=";

  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src;
    hash = "sha256-3o16ubb0Cp41fCup6vNyY1dxwZFZ4EfB1z8ytmZkc4k=";
  };

  nativeBuildInputs = [
    cargo-tauri.hook
    nodejs
    npmHooks.npmConfigHook
    pkg-config
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    openssl
    webkitgtk_4_1
    libsoup_3
  ];

  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;

  defaultTauriBundleType = "deb";

  doCheck = false; # doctests will fail

  meta = {
    description = "A Minecraft launcher from @SJMC-Dev (GPL-3.0 with custom additional licenses)";
    homepage = "https://mc.sjtu.cn/sjmcl";
    changelog = "https://github.com/UNIkeEN/SJMCL/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    maintainers = [ ];
    mainProgram = "SJMCL";
    platforms = lib.platforms.linux ++ lib.platforms.darwin; # darwin not tested
  };
})
