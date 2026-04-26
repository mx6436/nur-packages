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
  version = "2.1.1";

  src = fetchFromGitHub {
    owner = "MistEO";
    repo = "MXU";
    rev = "v${finalAttrs.version}";
    hash = "sha256-+8qsusrmZszXuEkNEj4/h70gnzj4a5S9caonePLw5U8=";
  };

  cargoHash = "sha256-Xd0RMzG7+M/nJvPz5sfPG8rt3s/AC09Ea1u5ma/l5ww=";
  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 3;
    pnpm = pnpm_10;
    hash = "sha256-Lt2fRAhEO4nmBmNG6TqBURRLfvLghhVIokVsqbL9Ufg=";
  };

  patches = [
    # mxu use executable directory as data directory, which is not allowed in Nix store.
    # This patch changes data directory to XDG data dir.
    ./linux-data-dir.patch
    ./tauri-capability.patch
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
