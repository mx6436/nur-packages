{
  lib,
  callPackage,
  fetchFromGitHub,
  fetchPnpmDeps,
  fetchurl,
  writeText,

  brotli,
  cargo-tauri,
  jq,
  nodejs,
  pnpm_12,
  pnpmConfigHook,
  pkg-config,
  rustPlatform,
  wrapGAppsHook3,

  glib,
  glib-networking,
  gsettings-desktop-schemas,
  libayatana-appindicator,
  libsoup_3,
  openssl,
  webkitgtk_4_1,

  dbip-country-lite,
  mihomo,
  v2ray-rules-dat,
}:

let

  pnpm = pnpm_12;

  nyanpasu-runtime = fetchFromGitHub {
    owner = "libnyanpasu";
    repo = "nyanpasu-runtime";
    rev = "90ac364c9c52ea05d62f18f00b53be80b3b32144";
    hash = "sha256-bgyk0zUVthr4kRQz6pefcd7ZyzGbPCK58gYCFK7aVQc=";
  };

  nyanpasu-utils = fetchFromGitHub {
    owner = "libnyanpasu";
    repo = "nyanpasu-utils";
    rev = "3db559fc60c586c59583df020fabd6247c43f8d7";
    hash = "sha256-5pIr/Kh+lVirWomtFAatncqm+0DGWQFa3Msv4/gW2bA=";
  };

  nyanpasu-service = callPackage ./nyanpasu-service.nix {
    inherit nyanpasu-runtime nyanpasu-utils;
  };

  boa-modules = {
    es-toolkit = fetchurl {
      url = "https://fastly.jsdelivr.net/npm/es-toolkit@1.39.10/+esm";
      hash = "sha256-M6ZXYKpCbN+5Q5pbxJVnvy7M7FFEnt0g0zd5T8Xilts=";
    };
    yaml = fetchurl {
      url = "https://fastly.jsdelivr.net/npm/yaml@2.8.1/+esm";
      hash = "sha256-wQ/cVzdEcsyTn/Y7EWp7OVG9gcnch6FBQZCgPek9eos=";
    };
    dedent = fetchurl {
      url = "https://fastly.jsdelivr.net/npm/dedent@1.7.0/+esm";
      hash = "sha256-RT7onzRx0WrmsLmu4jgtDPhcnLsV/U8VbDO8P45yZgI=";
    };
    js-base64 = fetchurl {
      url = "https://fastly.jsdelivr.net/npm/js-base64@3.7.8/+esm";
      hash = "sha256-3jLRvoyvK1Mgt/h6EuAXX60wuAe/GvafEl0oGxnuDEs=";
    };
  };

  inlang-plugins = {
    message-format = fetchurl {
      url = "https://fastly.jsdelivr.net/npm/@inlang/plugin-message-format@4/dist/index.js";
      hash = "sha256-AxykbtpQK6LsKeGnhkM56fNw5dIihY9jJfhJ3/3zkeM=";
    };
    m-function-matcher = fetchurl {
      url = "https://fastly.jsdelivr.net/npm/@inlang/plugin-m-function-matcher@2/dist/index.js";
      hash = "sha256-RnXf/UKOuYlPO/n/SrCBcI4K5hrUzRNfGm/1AIoaqbU=";
    };
  };

  # @inlang/sdk loads the inlang plugins with fetch(), which has no file:// support
  file-fetch-shim = writeText "fetch-file-url.mjs" ''
    const originalFetch = globalThis.fetch

    globalThis.fetch = async (input, init) => {
      const url =
        typeof input === 'string'
          ? input
          : input instanceof URL
            ? input.href
            : input.url

      if (url.startsWith('file://')) {
        const { readFile } = await import('node:fs/promises')
        return new Response(await readFile(new URL(url), 'utf8'))
      }

      return originalFetch(input, init)
    }
  '';

in

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "clash-nyanpasu";
  version = "2.0.1";

  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "libnyanpasu";
    repo = "clash-nyanpasu";
    tag = "v${finalAttrs.version}";
    hash = "sha256-lhxzDzwo2A6o5MYTlas6m2cHAVhrUU2h3wgCGWF4tmI=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 4;
    inherit pnpm;
    hash = "sha256-b2NJ7x+gy95xIf905EiXQhG4NFZdWpkNTBmPDnwfjgw=";
  };

  cargoHash = "sha256-yvvu5ee58/MaPUEsSpJbmx99qPKtWyjdGE6NadLHadw=";
  cargoRoot = "backend";
  buildAndTestSubdir = finalAttrs.cargoRoot;

  doCheck = false; # 编译时间过长，无法接受

  env.NODE_OPTIONS = "--import file://${file-fetch-shim}";

  postUnpack = ''
    cp -rT --no-preserve=mode ${nyanpasu-runtime} "source/backend/nyanpasu-runtime"
    cp -rT --no-preserve=mode ${nyanpasu-utils} "source/backend/nyanpasu-runtime/crates/nyanpasu-utils"
  '';

  postPatch = ''
    jq --arg messageFormat "file://${inlang-plugins.message-format}" \
      --arg functionMatcher "file://${inlang-plugins.m-function-matcher}" \
      '.modules = [ $messageFormat, $functionMatcher ]' \
      frontend/nyanpasu/project.inlang/settings.json > settings.json.new
    mv settings.json.new frontend/nyanpasu/project.inlang/settings.json

    jq '.build.beforeBuildCommand = "pnpm web:build"
        | del(.bundle.externalBin)
        | .bundle.createUpdaterArtifacts = false' \
      backend/tauri/tauri.conf.json > tauri.conf.json.new
    mv tauri.conf.json.new backend/tauri/tauri.conf.json

    mkdir -p backend/tauri/tmp
    jq -n \
      --arg hash "v${finalAttrs.version}" \
      --arg author "nixpkgs" \
      --arg time "1970-01-01T00:00:00Z" \
      '{ hash: $hash, author: $author, time: $time }' \
      > backend/tauri/tmp/git-info.json

    mkdir -p backend/tauri/resources
    ln -s ${v2ray-rules-dat}/share/v2ray/geoip.dat backend/tauri/resources/geoip.dat
    ln -s ${v2ray-rules-dat}/share/v2ray/geosite.dat backend/tauri/resources/geosite.dat
    ln -s ${dbip-country-lite.mmdb} backend/tauri/resources/Country.mmdb

    ${lib.concatLines (
      lib.mapAttrsToList (
        name: src:
        "${brotli}/bin/brotli -q 11 -w 22 -n -o backend/boa_utils/src/module/builtin/${name}.js.br ${src}"
      ) boa-modules
    )}

    substituteInPlace backend/boa_utils/src/module/builtin.rs \
      --replace-fail 'use include_url_macro::include_url_bytes_with_brotli;' "" \
      --replace-fail 'include_url_bytes_with_brotli!("https://fastly.jsdelivr.net/npm/es-toolkit@1.39.10/+esm")' 'include_bytes!("builtin/es-toolkit.js.br")' \
      --replace-fail 'include_url_bytes_with_brotli!("https://fastly.jsdelivr.net/npm/yaml@2.8.1/+esm")' 'include_bytes!("builtin/yaml.js.br")' \
      --replace-fail 'include_url_bytes_with_brotli!("https://fastly.jsdelivr.net/npm/dedent@1.7.0/+esm")' 'include_bytes!("builtin/dedent.js.br")' \
      --replace-fail 'include_url_bytes_with_brotli!("https://fastly.jsdelivr.net/npm/js-base64@3.7.8/+esm")' 'include_bytes!("builtin/js-base64.js.br")'
  '';

  postInstall = ''
    mv "$out/bin/Clash Nyanpasu" "$out/bin/clash-nyanpasu"
    mv "$out/share/applications/Clash Nyanpasu.desktop" "$out/share/applications/clash-nyanpasu.desktop"
    substituteInPlace "$out/share/applications/clash-nyanpasu.desktop" \
      --replace-fail 'Exec="Clash Nyanpasu"' 'Exec=clash-nyanpasu'
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libayatana-appindicator ]}
      --prefix PATH : ${lib.makeBinPath [ glib ]}
    )
  '';

  postFixup = ''
    ln -s ${mihomo}/bin/mihomo $out/bin/mihomo
    ln -s ${nyanpasu-service}/bin/nyanpasu-service $out/bin/nyanpasu-service
  '';

  nativeBuildInputs = [
    brotli
    cargo-tauri.hook
    jq
    nodejs
    pkg-config
    pnpm
    pnpmConfigHook
    wrapGAppsHook3
  ];

  buildInputs = [
    glib
    glib-networking
    gsettings-desktop-schemas
    libayatana-appindicator
    libsoup_3
    openssl
    webkitgtk_4_1
  ];

  meta = {
    description = "Clash GUI based on tauri";
    homepage = "https://github.com/libnyanpasu/clash-nyanpasu";
    changelog = "https://github.com/libnyanpasu/clash-nyanpasu/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Plus;
    mainProgram = "clash-nyanpasu";
    platforms = lib.platforms.linux;
  };
})
