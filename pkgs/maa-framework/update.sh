#!/usr/bin/env -S nix shell nixpkgs#bash nixpkgs#curl nixpkgs#jq nixpkgs#git nixpkgs#nix nixpkgs#python3 --command bash
# Update MaaFramework and the submodules pinned by its release tag.
set -euo pipefail

pkg_file="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/package.nix"
repo=MaaXYZ/MaaFramework

# releases/latest excludes pre-releases; use the first published, non-draft release.
curl_args=(-fsSL)
if [[ -n "${GITHUB_TOKEN:-${GH_TOKEN:-}}" ]]; then
  curl_args+=(-H "Authorization: Bearer ${GITHUB_TOKEN:-${GH_TOKEN:-}}")
fi
release=$(curl "${curl_args[@]}" "https://api.github.com/repos/$repo/releases?per_page=20")
tag=$(jq -er '[.[] | select(.draft | not)][0].tag_name | select(test("^v[0-9]"))' <<<"$release")
version=${tag#v}
current=$(python3 - "$pkg_file" <<'PY'
import re
import sys
from pathlib import Path

matches = re.findall(r'^  version = "([^"]+)";$', Path(sys.argv[1]).read_text(), re.M)
if len(matches) != 1:
    raise SystemExit('Expected exactly one version in package.nix')
print(matches[0])
PY
)
if [[ "$version" == "$current" ]]; then
  echo "Already up to date: $tag"
  exit 0
fi

echo "Updating MaaFramework: $current -> $version"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

git clone --quiet --filter=blob:none --no-checkout --depth 1 --branch "$tag" \
  "https://github.com/$repo.git" "$tmpdir/repo"

# The gitlink (not the submodule's latest branch) is the revision in this release.
submodule_rev() {
  local entry
  entry=$(git -C "$tmpdir/repo" ls-tree HEAD -- "$1")
  if [[ ! "$entry" =~ ^160000[[:space:]]commit[[:space:]]([0-9a-f]{40})[[:space:]] ]]; then
    echo "Cannot resolve submodule gitlink: $1" >&2
    return 1
  fi
  printf '%s\n' "${BASH_REMATCH[1]}"
}

prefetch() {
  local hash
  hash=$(nix-prefetch-url --unpack "https://github.com/$1/archive/$2.tar.gz")
  nix hash convert --hash-algo sha256 --to sri "$hash"
}

src_hash=$(prefetch "$repo" "$tag")
utils_rev=$(submodule_rev source/MaaUtils)
agent_rev=$(submodule_rev 3rdparty/MaaAgentBinary)
utils_hash=$(prefetch MaaXYZ/MaaUtils "$utils_rev")
agent_hash=$(prefetch MaaXYZ/MaaAgentBinary "$agent_rev")

# Validate the expected layout and all matches before writing anything.
python3 - "$pkg_file" "$current" "$version" "$src_hash" \
  "$utils_rev" "$utils_hash" "$agent_rev" "$agent_hash" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
current, version, src_hash, utils_rev, utils_hash, agent_rev, agent_hash = sys.argv[2:]
text = path.read_text()

def replace_once(pattern, replacement):
    global text
    text, count = re.subn(pattern, lambda _: replacement, text, count=1, flags=re.M)
    if count != 1:
        raise SystemExit(f'Expected exactly one match for {pattern!r}')

replace_once(r'^  version = "' + re.escape(current) + r'";$', f'  version = "{version}";')
for name, rev, hash_value in (
    ('MaaUtils', utils_rev, utils_hash),
    ('MaaAgentBinary', agent_rev, agent_hash),
):
    block = rf'(?P<head>^  {name} = fetchFromGitHub \{{\n)(?P<body>.*?)(?P<tail>^  \}};)'
    match = re.search(block, text, re.M | re.S)
    if not match:
        raise SystemExit(f'Missing fetchFromGitHub block: {name}')
    body = match.group('body')
    for field, value in (('rev', rev), ('hash', hash_value)):
        body, count = re.subn(rf'^    {field} = "[^"]+";$', f'    {field} = "{value}";', body, flags=re.M)
        if count != 1:
            raise SystemExit(f'Expected one {name}.{field}')
    text = text[:match.start()] + match.group('head') + body + match.group('tail') + text[match.end():]

src_block = r'(?P<head>^  src = fetchFromGitHub \{\n)(?P<body>.*?)(?P<tail>^  \};)'
match = re.search(src_block, text, re.M | re.S)
if not match:
    raise SystemExit('Missing src fetchFromGitHub block')
body, count = re.subn(r'^    sha256 = "[^"]+";$', f'    sha256 = "{src_hash}";', match.group('body'), flags=re.M)
if count != 1:
    raise SystemExit('Expected one src.sha256')
text = text[:match.start()] + match.group('head') + body + match.group('tail') + text[match.end():]
path.write_text(text)
PY

echo "Updated to $tag (src, MaaUtils, MaaAgentBinary)"
