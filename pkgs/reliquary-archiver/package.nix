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
  version = "0.16.0";

  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "IceDynamix";
    repo = "reliquary-archiver";
    tag = "v${finalAttrs.version}";
    hash = "sha256-HyA5Oy/UdaFb53Y7JPkrmSWHAXnER3S26vE+wSlUW3U=";
  };

  cargoHash = "sha256-pl45xKN+h6TKfJ5mPUtM8yJPYpTwgu238Z+Wp4Ye4Ds=";

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
