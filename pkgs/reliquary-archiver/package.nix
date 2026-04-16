{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  fetchurl,
  pkg-config,
  libpcap,
  wayland,
}:

let
  manifest = lib.importJSON ./manifest.json;

  baseUrl = "https://gitlab.com/Dimbreath/turnbasedgamedata/-/raw/${manifest.gameDataRev}";

  files = lib.mapAttrs (
    name: hash:
    let
      url =
        if name == "TextMapEN.json" then "${baseUrl}/TextMap/${name}" else "${baseUrl}/ExcelOutput/${name}";
    in
    fetchurl { inherit name url hash; }
  ) manifest.files;
in

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "reliquary-archiver";
  version = "0.14.2";

  src = fetchFromGitHub {
    owner = "IceDynamix";
    repo = "reliquary-archiver";
    rev = "9bd745ea4f33b9a47417dafb86e6a44ea9943ff9";
    hash = "sha256-4CgCjW++aBkLtSy06GNPpOqqPxKuv2iYtEWjA5Yt7sY=";
  };

  cargoHash = "sha256-MGZAgxbjNzTx3l4XU1txuZaqf6JzONq1RCIeXQZwuFI=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    libpcap
  ]
  ++ lib.optional stdenv.hostPlatform.isLinux wayland.dev;

  patches = [ ./fix-build.patch ];

  postPatch = ''
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: file: "ln -s ${file} ${name}") files)}
  '';

  passthru.updateScript = ./update.fish;

  meta = {
    description = "Tool to create a relic export from network packets of a certain turn-based anime game";
    homepage = "https://github.com/IceDynamix/reliquary-archiver";
    changelog = "https://github.com/IceDynamix/reliquary-archiver/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "reliquary-archiver";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
