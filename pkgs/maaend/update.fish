#!/usr/bin/env fish

# Updater for pkgs/maaend.
#
# Requires: fish, curl, jq, git, gnused, nix (with nix-prefetch-url) in PATH,
# and a nixpkgs checkout reachable through NIX_PATH (for the vendorHash probe).
# When run outside of such an environment, e.g. in CI, use:
#   nix shell nixpkgs#fish nixpkgs#nix nixpkgs#jq nixpkgs#curl nixpkgs#gnused nixpkgs#git \
#     --command fish pkgs/maaend/update.fish

for tool in curl jq git sed nix nix-prefetch-url
    if not command -q $tool
        echo "ERROR: '$tool' is required but was not found in PATH" >&2
        exit 1
    end
end

set repo MaaEnd/MaaEnd
set pkg_file pkgs/maaend/package.nix

# submodules fetched as tarballs: <path> <GitHub repo> <nix var prefix>
set submodules \
    "agent/cpp-algo/MaaUtils MaaXYZ/MaaUtils maaUtils" \
    "assets/resource/model MaaEnd/MaaEnd-AI maaendAi"

# test fixtures only, not packaged
set ignored_submodules tests/MaaEndTestset

echo "--- Fetching latest release ---"

# The GitHub API is rate limited for unauthenticated requests (HTTP 403),
# so use a token when one is available.
set api_token $GITHUB_TOKEN
if test -z "$api_token"
    set api_token $GH_TOKEN
end
if test -z "$api_token"; and command -q gh
    set api_token (gh auth token 2>/dev/null)
end

set curl_args -fsS
if test -n "$api_token"
    set -a curl_args -H "Authorization: Bearer $api_token"
end

set tag_name
set response (curl $curl_args "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null)
if test -n "$response"
    set tag_name (echo $response | jq -er '.tag_name' 2>/dev/null)
end

if test -z "$tag_name"
    # Fall back to the tag list, skipping pre-release tags (v1.2.3-rc.1, ...).
    echo "GitHub API unavailable (rate limited?), falling back to git ls-remote"
    set tags (git ls-remote --tags --refs --sort=v:refname "https://github.com/$repo" \
        | string replace -r '^.*refs/tags/' '' \
        | string match -rv -- '-')
    if test -n "$tags"
        set tag_name $tags[-1]
    end
end

if test -z "$tag_name"
    echo "ERROR: Failed to determine the latest stable release"
    exit 1
end

set new_version (string replace -r '^v' '' $tag_name)

set current_version (sed -n -E 's/^  version = "(.*)";$/\1/p' $pkg_file)
if test -z "$current_version"
    echo "ERROR: Failed to read current version from $pkg_file"
    exit 1
end
if test "$current_version" = "$new_version"
    echo "Already up to date: v$new_version"
    exit 0
end

echo "Updating: $current_version -> $new_version"

set tmpdir (mktemp -d)

function cleanup_tempdir --on-event fish_exit --on-signal INT --on-signal TERM
    rm -rf $tmpdir
end

echo "--- Computing srcHash ---"
set src_hash (nix-prefetch-url --unpack "https://github.com/$repo/archive/$tag_name.tar.gz" 2>/dev/null)
if test -z "$src_hash"
    echo "ERROR: Failed to compute srcHash"
    exit 1
end
set src_hash (nix hash convert --hash-algo sha256 --to sri $src_hash)
echo "srcHash: $src_hash"

echo "--- Resolving submodule revisions ---"
git clone --quiet --filter=blob:none --no-checkout --depth 1 --branch $tag_name "https://github.com/$repo" $tmpdir/repo
or begin
    echo "ERROR: Failed to clone $repo at $tag_name"
    exit 1
end

git -C $tmpdir/repo show HEAD:.gitmodules > $tmpdir/gitmodules
set declared_paths (git config -f $tmpdir/gitmodules --get-regexp '\.path$' | string replace -r '^\S+\s+' '')

set sed_args
set mapped_paths
for entry in $submodules
    set fields (string split ' ' -- $entry)
    set path $fields[1]
    set slug $fields[2]
    set prefix $fields[3]
    set -a mapped_paths $path

    set rev (string match -rg '^160000 commit ([0-9a-f]+)' -- (git -C $tmpdir/repo ls-tree HEAD $path))
    if test -z "$rev"
        echo "ERROR: Failed to resolve submodule revision for $path"
        exit 1
    end

    set sub_hash (nix-prefetch-url --unpack "https://github.com/$slug/archive/$rev.tar.gz" 2>/dev/null)
    if test -z "$sub_hash"
        echo "ERROR: Failed to compute hash for $slug at $rev"
        exit 1
    end
    set sub_hash (nix hash convert --hash-algo sha256 --to sri $sub_hash)

    set rev_var "$prefix"Rev
    set hash_var "$prefix"Hash

    echo "$path: $rev"
    echo "$hash_var: $sub_hash"

    set -a sed_args -e "s|^  $rev_var = \".*\";\$|  $rev_var = \"$rev\";|"
    set -a sed_args -e "s|^  $hash_var = \".*\";\$|  $hash_var = \"$sub_hash\";|"
end

for declared in $declared_paths
    if contains -- $declared $mapped_paths; or contains -- $declared $ignored_submodules
        continue
    end
    echo "WARNING: upstream submodule $declared is not handled by this script"
end

echo "--- Computing vendorHash ---"
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

echo "--- Writing $pkg_file ---"
sed -i -E \
    -e "s|^  version = \".*\";\$|  version = \"$new_version\";|" \
    -e "s|^  srcHash = \".*\";\$|  srcHash = \"$src_hash\";|" \
    -e "s|^  vendorHash = \".*\";\$|  vendorHash = \"$vendor_hash\";|" \
    $sed_args $pkg_file

echo "--- Updated to v$new_version ---"
