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
  version = "0.8.3";

  src = fetchFromGitHub {
    owner = "UNIkeEN";
    repo = "SJMCL";
    rev = "v${finalAttrs.version}";
    hash = "sha256-w+/qr+jndkyfjKyCaVPQnarUROahD7xEWY06nlc4jZM=";
  };

  cargoHash = "sha256-kui9FVuknNHtP30f08vvSjWJOaNIWvil/ruQqxtKqys=";

  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src;
    hash = "sha256-bOlKbuhyFifjnSB7eeVXAT0aVC8Vxp7DiR7D8vJE8LU=";
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
    description = "A Minecraft launcher from @SJMC-Dev";
    homepage = "https://mc.sjtu.cn/sjmcl";
    changelog = "https://github.com/UNIkeEN/SJMCL/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    maintainers = [ ];
    mainProgram = "SJMCL";
    platforms = lib.platforms.linux ++ lib.platforms.darwin; # darwin not tested
  };
})
