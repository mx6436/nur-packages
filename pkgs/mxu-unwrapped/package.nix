{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,

  cargo-tauri,
  nodejs,
  pnpm_10,
  pnpmConfigHook,
  pkg-config,
  rustPlatform,

  libayatana-appindicator,
  openssl,
  webkitgtk_4_1,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "mxu-unwrapped";
  version = "2.1.4";

  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "MistEO";
    repo = "MXU";
    rev = "v${finalAttrs.version}";
    hash = "sha256-FRtymkFr6FgehLSL73iSHIdBr3vi8+E6jFqom8PIttY=";
  };

  cargoHash = "sha256-YmsSxxyOiMiIEmf3Pnh5mHEuS5vg02J3KhMCEcHtcBA=";
  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 3;
    pnpm = pnpm_10;
    hash = "sha256-Lt2fRAhEO4nmBmNG6TqBURRLfvLghhVIokVsqbL9Ufg=";
  };

  patches = [
    # Read app data dir from MXU_DATA_DIR / XDG_DATA_HOME / HOME.
    ./0001-data-dir.patch
    # Allow plugin-fs access to MXU data directories.
    ./0002-capability.patch
  ];

  # write version to config files, as what they should be
  postPatch = ''
    substituteInPlace src-tauri/tauri.conf.json --replace-fail \
      "0.1.0" "${finalAttrs.version}"

    substituteInPlace src-tauri/Cargo.toml --replace-fail \
      "0.1.0" "${finalAttrs.version}"
  '';

  nativeBuildInputs = [
    cargo-tauri.hook
    nodejs
    pkg-config
    pnpm_10
    pnpmConfigHook
  ];

  buildInputs = [
    libayatana-appindicator
    openssl
    webkitgtk_4_1
  ];

  defaultTauriBundleType = "deb";

  meta = {
    description = "MaaFramework Next UI";
    homepage = "https://github.com/MistEO/MXU";
    changelog = "https://github.com/MistEO/MXU/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "mxu";
    platforms = lib.platforms.linux;
  };
})
