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
  sources = lib.importJSON ./sources.json;

  baseUrl = "https://gitlab.com/Dimbreath/turnbasedgamedata/-/raw/${sources.gameDataRev}";

  resources = lib.mapAttrs (
    name: hash:
    let
      url =
        if name == "TextMapEN.json" then "${baseUrl}/TextMap/${name}" else "${baseUrl}/ExcelOutput/${name}";
    in
    fetchurl { inherit name url hash; }
  ) sources.resources;
in

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "reliquary-archiver";
  version = "0.13.3";

  src = fetchFromGitHub {
    owner = "IceDynamix";
    repo = "reliquary-archiver";
    rev = "28933c85103ce97ad128c5f01b15f3851f2b0ddd";
    hash = "sha256-xDJLCB5BooRl78oz2WSMRdvZYX4/Ru+0ZJfN9RjPWXY=";
  };

  cargoHash = "sha256-1mZ5d4GMCKRMMEO2krGYmgNt4MgGBmjE94ER1V9s31I=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    libpcap
  ]
  ++ lib.optional stdenv.hostPlatform.isLinux wayland.dev;

  patches = [ ./fix-build.patch ];

  postPatch = ''
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: file: "ln -s ${file} ${name}") resources)}
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
