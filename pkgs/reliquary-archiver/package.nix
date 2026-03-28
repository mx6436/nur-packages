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
  version = "0.14.0";

  src = fetchFromGitHub {
    owner = "IceDynamix";
    repo = "reliquary-archiver";
    rev = "8bea7204d088cb358dec963f6bc4d1987c963f35";
    hash = "sha256-GbivI0UpNrjUJUMroZHxhjxjUeK//aKYOdoHwWSiE08=";
  };

  cargoHash = "sha256-vlfc6pfK5nMpaL7NbrenE7OJqZQvESEDHBEA+Nxy2+M=";

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
