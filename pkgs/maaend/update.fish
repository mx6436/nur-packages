#!/usr/bin/env -S nix shell nixpkgs#fish nixpkgs#nix nixpkgs#jq nixpkgs#curl nixpkgs#nix-prefetch-git --command fish

set repo MaaEnd/MaaEnd
set json_file pkgs/maaend/version.json

echo "--- Fetching latest release ---"

set response (curl -fsS "https://api.github.com/repos/$repo/releases?per_page=1")
or begin
    echo "ERROR: Failed to fetch release info"
    exit 1
end

set tag_name (echo $response | jq -er '.[0].tag_name')
or begin
    echo "ERROR: Failed to parse tag_name"
    exit 1
end
set is_prerelease (echo $response | jq -er '.[0].prerelease')
or begin
    echo "ERROR: Failed to parse prerelease flag"
    exit 1
end
set new_version (string replace -r '^v' '' $tag_name)

set variant stable
if test "$is_prerelease" = true
    set variant beta
end
echo "Latest: $tag_name (variant: $variant)"

set current_version (jq -r ".$variant.version" $json_file)
if test "$current_version" = "$new_version"
    echo "Already up to date: v$new_version"
    exit 0
end

echo "Updating $variant: $current_version -> $new_version"

echo "--- Computing srcHash ---"
set git_result (nix-prefetch-git --url "https://github.com/$repo" --rev "$tag_name" --fetch-submodules 2>/dev/null)
or begin
    echo "ERROR: Failed to run nix-prefetch-git"
    exit 1
end
set src_hash (echo $git_result | jq -er .hash)
or begin
    echo "ERROR: Failed to parse srcHash from nix-prefetch-git output"
    exit 1
end
echo "srcHash: $src_hash"

echo "--- Computing vendorHash ---"
set tmpdir (mktemp -d)

function cleanup_tempdir --on-event fish_exit --on-signal INT --on-signal TERM
    rm -rf $tmpdir
end

set temp_nix $tmpdir/vendor-fetch.nix
echo '
{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:
buildGoModule {
  pname = "maaend-go-service";
  version = "'"$new_version"'";
  src = fetchFromGitHub {
    owner = "MaaEnd";
    repo = "MaaEnd";
    rev = "'"$tag_name"'";
    hash = "'"$src_hash"'";
    fetchSubmodules = true;
  };
  vendorHash = lib.fakeHash;
  modRoot = "agent/go-service";
  subPackages = [ "." ];
}
' > $temp_nix

set build_output (nix build --impure --expr "(import $temp_nix { inherit (import <nixpkgs> {}) buildGoModule fetchFromGitHub lib; })" --no-link 2>&1; or true)
set vendor_hash (echo "$build_output" | string match -rg 'got:\s+(sha256-\S+)')

if test -z "$vendor_hash"
    echo "ERROR: Failed to extract vendorHash from build output"
    echo "$build_output"
    exit 1
end

echo "vendorHash: $vendor_hash"

echo "--- Writing version.json ---"
jq --arg ver "$new_version" --arg src "$src_hash" --arg vendor "$vendor_hash" \
    ".$variant.version = \$ver | .$variant.srcHash = \$src | .$variant.vendorHash = \$vendor" \
    $json_file > $json_file.tmp
mv $json_file.tmp $json_file

echo "--- Updated $variant to v$new_version ---"
