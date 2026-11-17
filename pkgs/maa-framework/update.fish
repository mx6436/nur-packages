#!/usr/bin/env -S nix shell nixpkgs#fish nixpkgs#curl nixpkgs#jq nixpkgs#gnused nixpkgs#git nixpkgs#nix --command fish

set repo MaaXYZ/MaaFramework
set pkg_file (path resolve (status dirname))/package.nix

set submodules \
    "source/MaaUtils MaaXYZ/MaaUtils MaaUtils" \
    "3rdparty/MaaAgentBinary MaaXYZ/MaaAgentBinary MaaAgentBinary"

set tmpdir (mktemp -d)

function cleanup_tmpdir --on-event fish_exit --on-signal INT --on-signal TERM
    rm -rf $tmpdir
end

function submodule_rev --argument-names sub_path
    set -l rev (string match -rg '^160000 commit ([0-9a-f]{40})' -- \
        (git -C $tmpdir/repo ls-tree $tag -- $sub_path))
    if test (count $rev) -ne 1
        echo "ERROR: Cannot resolve the submodule gitlink: $sub_path" >&2
        return 1
    end
    echo $rev
end

function prefetch_hash --argument-names slug rev
    set -l packed (nix-prefetch-url --unpack "https://github.com/$slug/archive/$rev.tar.gz" 2>/dev/null)
    if test -z "$packed"
        return 1
    end
    nix hash convert --hash-algo sha256 --to sri $packed
end

function block_of --argument-names binding
    sed -n -E "/^  $binding = fetchFromGitHub [{]\$/,/^  [}];\$/p" $work_file
end

echo "--- Fetching the latest release ---"

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

set tag (curl $curl_args "https://api.github.com/repos/$repo/releases?per_page=20" 2>/dev/null \
    | jq -er '[.[] | select(.draft | not)][0].tag_name | select(test("^v[0-9]"))' 2>/dev/null)
if test -z "$tag"
    echo "ERROR: Failed to determine the latest release of $repo"
    exit 1
end

set new_version (string replace -r '^v' '' $tag)
set current (string match -rg '^  version = "(.*)";$' <$pkg_file)
if test (count $current) -ne 1
    echo "ERROR: Expected exactly one version in $pkg_file"
    exit 1
end
if test "$current" = "$new_version"
    echo "Already up to date: $tag"
    exit 0
end

echo "Updating MaaFramework: $current -> $new_version"

echo "--- Resolving submodule revisions ---"
git clone --quiet --filter=blob:none --no-checkout --depth 1 \
    "https://github.com/$repo.git" $tmpdir/repo
or begin
    echo "ERROR: Failed to clone $repo"
    exit 1
end
git -C $tmpdir/repo fetch --quiet --filter=blob:none --depth 1 origin tag $tag
or begin
    echo "ERROR: Failed to fetch $tag from $repo"
    exit 1
end

set revisions
for entry in $submodules
    set fields (string split ' ' -- $entry)
    set sub_path $fields[1]
    set slug $fields[2]
    set binding $fields[3]

    set rev (submodule_rev $sub_path)
    or exit 1

    echo "$sub_path: $rev"
    set -a revisions "$binding $slug $rev"
end

echo "--- Computing hashes ---"
set src_hash (prefetch_hash $repo $tag)
if test -z "$src_hash"
    echo "ERROR: Failed to compute the src hash"
    exit 1
end
echo "$repo: $src_hash"

set sed_args
set pins
for entry in $revisions
    set fields (string split ' ' -- $entry)
    set binding $fields[1]
    set slug $fields[2]
    set rev $fields[3]

    set sub_hash (prefetch_hash $slug $rev)
    if test -z "$sub_hash"
        echo "ERROR: Failed to compute the hash for $slug at $rev"
        exit 1
    end

    echo "$binding: $sub_hash"
    set -a pins "$binding $rev $sub_hash"

    set -a sed_args -e "/^  $binding = fetchFromGitHub [{]\$/,/^  [}];\$/ s|^    rev = \".*\";\$|    rev = \"$rev\";|"
    set -a sed_args -e "/^  $binding = fetchFromGitHub [{]\$/,/^  [}];\$/ s|^    hash = \".*\";\$|    hash = \"$sub_hash\";|"
end

echo "--- Writing $pkg_file ---"
set work_file $tmpdir/package.nix
cp $pkg_file $work_file
sed -i -E \
    -e "s|^  version = \".*\";\$|  version = \"$new_version\";|" \
    -e "/^  src = fetchFromGitHub [{]\$/,/^  [}];\$/ s|^    sha256 = \".*\";\$|    sha256 = \"$src_hash\";|" \
    $sed_args $work_file
or begin
    echo "ERROR: Failed to update $pkg_file"
    exit 1
end

set pkg_content (cat $work_file)
if not string match -q -- "*  version = \"$new_version\";*" $pkg_content
    echo "ERROR: version was not written to $pkg_file"
    exit 1
end
if not string match -q -- "*sha256 = \"$src_hash\";*" (block_of src)
    echo "ERROR: src.sha256 was not written to $pkg_file"
    exit 1
end
for pin in $pins
    set fields (string split ' ' -- $pin)
    set block (block_of $fields[1])
    if not string match -q -- "*rev = \"$fields[2]\";*" $block
        echo "ERROR: $fields[1].rev was not written to $pkg_file"
        exit 1
    end
    if not string match -q -- "*hash = \"$fields[3]\";*" $block
        echo "ERROR: $fields[1].hash was not written to $pkg_file"
        exit 1
    end
end

mv $work_file $pkg_file
echo "--- Updated to $tag ---"
