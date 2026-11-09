{
  aws-lc,
  lib,
  nyanpasu-runtime,
  nyanpasu-utils,
  pkg-config,
  rustPlatform,
  writeShellScriptBin,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "nyanpasu-service";
  version = "2.0.2-unstable-2026-10-30";

  src = nyanpasu-runtime;

  cargoHash = "sha256-GpVY/V+Rg9eh3VLoGy1xUrpG3F7Ijh5rIudrkcRNDEU=";

  cargoBuildFlags = [
    "--package"
    "nyanpasu-service"
  ];
  doCheck = false;

  # nyanpasu-service-runtime uses #![feature(error_generic_member_access)]
  # and #[backtrace] on thiserror variants.
  env.RUSTC_BOOTSTRAP = "1";

  postUnpack = ''
    cp -rT --no-preserve=mode ${nyanpasu-utils} source/crates/nyanpasu-utils
  '';

  # build.rs shells out to `git show` for the commit stamp
  nativeBuildInputs = [
    pkg-config
    (writeShellScriptBin "git" ''
      printf "'%s,%s,%s'" \
        "90ac364c9c52ea05d62f18f00b53be80b3b32144" \
        "nixpkgs" \
        "1970-01-01T00:00:00.000Z"
    '')
  ];

  buildInputs = [
    aws-lc
  ];

  meta = {
    description = "Cross platform privileged service for Nyanpasu";
    homepage = "https://github.com/libnyanpasu/nyanpasu-runtime";
    changelog = "https://github.com/libnyanpasu/nyanpasu-runtime/releases";
    license = lib.licenses.gpl3Plus;
    mainProgram = "nyanpasu-service";
    platforms = lib.platforms.linux;
  };
})
