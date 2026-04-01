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
  wrapGAppsHook3,

  glib-networking,
  libayatana-appindicator,
  libsoup_3,
  openssl,
  webkitgtk_4_1,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "mxu";
  version = "1.21.3";

  src = fetchFromGitHub {
    owner = "MistEO";
    repo = "MXU";
    rev = "v${finalAttrs.version}";
    hash = "sha256-YU0Klo8kzejeDgINKMWecOOtJgBEdrrAVnVXoRu70kc=";
  };

  cargoHash = "sha256-EE7Lj4IVN0ZPF7Fg2QdlngXTH+u5ttQv3Vv+P0xKv4c=";
  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 3;
    pnpm = pnpm_10;
    hash = "sha256-uzmNEimPNf8XHNXQfnWRwb+0A6Q8XaNQJttwHoG9RvQ=";
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
    wrapGAppsHook3
  ];

  buildInputs = [
    glib-networking
    libayatana-appindicator
    libsoup_3
    openssl
    webkitgtk_4_1
  ];

  # buildType = "debug";

  # tauriBuildFlags = [ "--debug" ];

  defaultTauriBundleType = "deb";

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libayatana-appindicator ]}
    )
  '';

  meta = {
    description = "MaaFramework Next UI";
    homepage = "https://github.com/MistEO/MXU";
    changelog = "https://github.com/MistEO/MXU/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "mxu";
    platforms = lib.platforms.linux;
  };
})
