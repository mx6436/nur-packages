{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,

  cargo-tauri,
  nodejs,
  pnpm_12,
  pnpmConfigHook,
  pkg-config,
  rustPlatform,

  libayatana-appindicator,
  openssl,
  webkitgtk_4_1,
}:

let
  pnpm = pnpm_12;
in

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "mxu-unwrapped";
  version = "2.9.0";

  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "MistEO";
    repo = "MXU";
    tag = "v${finalAttrs.version}";
    hash = "sha256-+guxrtYOLw/JfXs/rswQP0m4i+nTDGAqWmfGaVBOw+o=";
  };

  cargoHash = "sha256-9Maqma1/Hipzc/OMIcJfvQklz9I+OHRRGo+AN4wDu3g=";
  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;

  buildFeatures = [
    "xdg-data-dir"
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 4;
    inherit pnpm;
    hash = "sha256-viicjbQj1AEpvR4FOBFsKPUKlcV/2/3B3/9xLnuW7Uk=";
  };

  patches = [
    ./disable-auto-update.patch
    ./xdg-data-dir.patch
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
    pnpm
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
